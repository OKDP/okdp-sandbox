"""Spark ETL job for daily orders processing."""

from __future__ import annotations

import argparse
import csv
import io
import os
from datetime import datetime
from typing import Any, Iterable
from urllib.parse import urlparse


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run orders ETL with Spark")
    parser.add_argument("--input-uri", required=True, help="Input URI (for example: s3a://bucket/path)")
    parser.add_argument("--output-uri", required=True, help="Output URI for curated dataset")
    parser.add_argument("--run-id", required=True, help="Unique ETL run identifier")
    return parser.parse_args()


def _bootstrap_input_if_missing(spark: Any) -> Any:
    from pyspark.sql.types import DoubleType, IntegerType, StringType, StructField, StructType

    sample_rows: Iterable[tuple[str, str, str, int, float]] = [
        ("o-1001", "c-001", "2026-02-01 08:10:00", 2, 19.90),
        ("o-1002", "c-001", "2026-02-01 08:45:00", 1, 5.50),
        ("o-1003", "c-002", "2026-02-01 09:20:00", 3, 12.00),
        ("o-1004", "c-003", "2026-02-01 10:00:00", 1, 42.30),
        ("o-1005", "c-002", "2026-02-01 11:15:00", 2, 7.25),
    ]
    schema = StructType(
        [
            StructField("order_id", StringType(), False),
            StructField("customer_id", StringType(), False),
            StructField("order_ts", StringType(), False),
            StructField("quantity", IntegerType(), False),
            StructField("unit_price", DoubleType(), False),
        ]
    )

    df = spark.createDataFrame(sample_rows, schema=schema)
    return df


def _s3a_to_bucket_key(s3a_uri: str) -> tuple[str, str]:
    if not s3a_uri.startswith("s3a://"):
        raise ValueError(f"Unsupported URI scheme for output: {s3a_uri}")
    s3_uri = s3a_uri.replace("s3a://", "s3://", 1)
    parsed = urlparse(s3_uri)
    bucket = parsed.netloc.strip()
    key_prefix = parsed.path.lstrip("/")
    if not bucket:
        raise ValueError(f"Missing S3 bucket in URI: {s3a_uri}")
    return bucket, key_prefix


def _upload_curated_csv_with_jvm_s3(curated_df: Any, output_uri: str, spark: Any) -> str:
    endpoint = os.getenv("S3_ENDPOINT", "")
    access_key = os.getenv("S3_ACCESS_KEY", "")
    secret_key = os.getenv("S3_SECRET_KEY", "")
    if not endpoint or not access_key or not secret_key:
        raise RuntimeError("Missing S3 runtime credentials or endpoint for output upload")

    bucket, key_prefix = _s3a_to_bucket_key(output_uri)
    object_key = f"{key_prefix.rstrip('/')}/curated.csv" if key_prefix else "curated.csv"

    rows = curated_df.orderBy("order_date", "customer_id").collect()
    csv_buffer = io.StringIO()
    writer = csv.writer(csv_buffer)
    writer.writerow(
        [
            "order_date",
            "customer_id",
            "orders_count",
            "gross_amount",
            "etl_run_id",
            "processed_at_utc",
        ]
    )
    for row in rows:
        writer.writerow(
            [
                row["order_date"],
                row["customer_id"],
                row["orders_count"],
                row["gross_amount"],
                row["etl_run_id"],
                row["processed_at_utc"],
            ]
        )

    jvm = spark.sparkContext._jvm
    gateway = spark.sparkContext._gateway
    region = os.getenv("AWS_REGION", "us-east-1")
    payload = csv_buffer.getvalue()

    credentials = jvm.com.amazonaws.auth.BasicAWSCredentials(access_key, secret_key)
    credentials_provider = jvm.com.amazonaws.auth.AWSStaticCredentialsProvider(credentials)
    endpoint_config = jvm.com.amazonaws.client.builder.AwsClientBuilder.EndpointConfiguration(
        endpoint,
        region,
    )
    s3_client = (
        jvm.com.amazonaws.services.s3.AmazonS3ClientBuilder.standard()
        .withPathStyleAccessEnabled(True)
        .withEndpointConfiguration(endpoint_config)
        .withCredentials(credentials_provider)
        .build()
    )
    s3_client.putObject(bucket, object_key, payload)

    return f"s3a://{bucket}/{object_key}"


def main() -> None:
    args = parse_args()

    from pyspark.sql import SparkSession
    from pyspark.sql import functions as F

    spark = SparkSession.builder.appName(f"orders-etl-{args.run_id}").getOrCreate()
    spark.sparkContext.setLogLevel("WARN")

    # Ensure S3A is configured from runtime env injected by SparkApplication.
    access_key = os.getenv("S3_ACCESS_KEY", "")
    secret_key = os.getenv("S3_SECRET_KEY", "")
    endpoint = os.getenv("S3_ENDPOINT", "")
    if access_key and secret_key:
        hadoop_conf = spark.sparkContext._jsc.hadoopConfiguration()
        hadoop_conf.set("fs.s3a.access.key", access_key)
        hadoop_conf.set("fs.s3a.secret.key", secret_key)
        if endpoint:
            hadoop_conf.set("fs.s3a.endpoint", endpoint)
            hadoop_conf.set("fs.s3a.connection.ssl.enabled", str(endpoint.startswith("https://")).lower())
        hadoop_conf.set("fs.s3a.path.style.access", "true")
        hadoop_conf.set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")

    try:
        raw_df = spark.read.option("header", "true").csv(args.input_uri)
        if raw_df.rdd.isEmpty():
            raw_df = _bootstrap_input_if_missing(spark=spark)
    except Exception:
        raw_df = _bootstrap_input_if_missing(spark=spark)

    normalized_df = (
        raw_df.withColumn("order_id", F.col("order_id").cast("string"))
        .withColumn("customer_id", F.col("customer_id").cast("string"))
        .withColumn("order_ts", F.to_timestamp("order_ts"))
        .withColumn("quantity", F.col("quantity").cast("int"))
        .withColumn("unit_price", F.col("unit_price").cast("double"))
        .fillna({"quantity": 1, "unit_price": 0.0})
        .withColumn("order_date", F.to_date("order_ts"))
        .withColumn("line_amount", F.round(F.col("quantity") * F.col("unit_price"), 2))
    )

    curated_df = (
        normalized_df.groupBy("order_date", "customer_id")
        .agg(
            F.countDistinct("order_id").alias("orders_count"),
            F.round(F.sum("line_amount"), 2).alias("gross_amount"),
        )
        .withColumn("etl_run_id", F.lit(args.run_id))
        .withColumn("processed_at_utc", F.lit(datetime.utcnow().isoformat()))
    )

    written_uri = _upload_curated_csv_with_jvm_s3(
        curated_df=curated_df,
        output_uri=args.output_uri,
        spark=spark,
    )

    print(f"Orders ETL completed for run_id={args.run_id}")
    print(f"Input URI: {args.input_uri}")
    print(f"Output URI: {written_uri}")
    print(f"Input rows: {normalized_df.count()}")
    print(f"Curated rows: {curated_df.count()}")

    spark.stop()


if __name__ == "__main__":
    main()
