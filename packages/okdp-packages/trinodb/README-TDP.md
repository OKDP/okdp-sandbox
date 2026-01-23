# Trino TDP Integration Guide

This document outlines the steps to configure and deploy the necessary Kubernetes resources for integrating Trino with TDP, enabling support for Kerberos authentication, Hive, and HDFS query federation.

## Prerequisites

Ensure you have the following files available in your `../tdp-client` directory. **Note: Configuration files are auto-generated in the TDP environment.**

- `trino.keytab`: Kerberos keytab for the Trino service principal.
- `tdp_ca.crt`: The CA certificate for the TDP cluster.
- Hadoop configuration files (`core-site.xml`, `hdfs-site.xml`, `hive-site.xml`) and `krb5.conf`.

---

## 1. Secrets Management

Run the following commands to create the required Kubernetes secrets. These secrets store sensitive authentication materials.

### Create Trino Keytab Secret
```bash
kubectl create secret generic trino-keytab \
  --from-file=trino.keytab=../tdp-client/trino.keytab \
  --namespace=default
```

### Create CA Certificate Secret
```bash
kubectl create secret generic tdp-ca-cert \
  --from-file=tdp_ca.crt=../tdp-client/tdp_ca.crt \
  --namespace=default
```

**Verification:**
You can verify the secrets layout using `kubectl describe`:

```yaml
Name:         tdp-ca-cert
Namespace:    default
Type:         Opaque
Data:
  tdp_ca.crt: 1887 bytes

Name:         trino-keytab
Namespace:    default
Type:         Opaque
Data:
  trino.keytab: 433 bytes
```

---

## 2. Hadoop Client Configuration

The `hadoop-client-config` ConfigMap is essential for Trino to communicate with the HDFS and Hive Metastore services. It contains the standard Hadoop XML configuration files and the Kerberos configuration, which are **auto-generated** in the TDP client directory.

### Create ConfigMap
Navigate to the directory containing your configuration files (e.g., `../tdp-client/hadoop-client`) and run:

```bash
kubectl create configmap hadoop-client-config \
  --from-file=. \
  --namespace=default
```

---

## 3. Configuration Reference

Below are examples of the **auto-generated** configurations included in the `hadoop-client-config` ConfigMap. These are provided for reference.

### core-site.xml
Defines the default filesystem, Zookeeper quorum, and proxy user settings.

```xml
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://mycluster</value>
  </property>
  <property>
    <name>ha.zookeeper.quorum</name>
    <value>master-01.tdp:2181,master-02.tdp:2181,master-03.tdp:2181</value>
  </property>
  <property>
    <name>ha.zookeeper.acl</name>
    <value>sasl:nn:rwcda</value>
  </property>
  <property>
    <name>hadoop.security.authentication</name>
    <value>kerberos</value>
  </property>
  <property>
    <name>hadoop.security.authorization</name>
    <value>true</value>
  </property>
  <property>
    <name>hadoop.security.auth_to_local</name>
    <value>
      RULE:[2:$1/$2@$0]([ndj]n/.*@REALM.TDP)s/.*/hdfs/
      RULE:[1:$1@$0](hdfs@REALM.TDP)s/.*/hdfs/
      RULE:[2:$1/$2@$0](trino/.*@REALM.TDP)s/.*/trino/
      RULE:[2:$1/$2@$0](hive/.*@REALM.TDP)s/.*/hive/
      DEFAULT
    </value>
  </property>
  <!-- Proxy User Settings -->
  <property>
    <name>hadoop.proxyuser.trino.hosts</name>
    <value>*</value>
  </property>
  <property>
    <name>hadoop.proxyuser.trino.groups</name>
    <value>*</value>
  </property>
  <property>
    <name>hadoop.proxyuser.hive.hosts</name>
    <value>*</value>
  </property>
  <property>
    <name>hadoop.proxyuser.hive.groups</name>
    <value>*</value>
  </property>
</configuration>
```

### hdfs-site.xml
Configures HDFS High Availability (HA), NameNode RPC addresses, and Kerberos principals.

```xml
<configuration>
  <property>
    <name>dfs.nameservices</name>
    <value>mycluster</value>
  </property>
  <property>
    <name>dfs.ha.namenodes.mycluster</name>
    <value>nn1,nn2</value>
  </property>
  <property>
    <name>dfs.namenode.rpc-address.mycluster.nn1</name>
    <value>master-01.tdp:8020</value>
  </property>
  <property>
    <name>dfs.namenode.rpc-address.mycluster.nn2</name>
    <value>master-02.tdp:8020</value>
  </property>
  <property>
    <name>dfs.client.failover.proxy.provider.mycluster</name>
    <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.principal</name>
    <value>nn/_HOST@REALM.TDP</value>
  </property>
  <property>
    <name>dfs.datanode.kerberos.principal</name>
    <value>dn/_HOST@REALM.TDP</value>
  </property>
  <property>
    <name>dfs.data.transfer.protection</name>
    <value>authentication</value>
  </property>
</configuration>
```

### hive-site.xml
Configures the Hive Metastore connection and Thrift protocol.

```xml
<configuration>
  <property>
    <name>hive.zookeeper.quorum</name>
    <value>master-01.tdp:2181,master-02.tdp:2181,master-03.tdp:2181</value>
  </property>
  <property>
    <name>hive.metastore.sasl.enabled</name>
    <value>true</value>
  </property>
  <property>
    <name>metastore.kerberos.principal</name>
    <value>hive/_HOST@REALM.TDP</value>
  </property>
  <property>
    <name>metastore.thrift.uris</name>
    <value>thrift://master-02.tdp:9083,thrift://master-03.tdp:9083</value>
  </property>
</configuration>
```

### krb5.conf
Standard Kerberos configuration for the TDP realm.

```ini
[libdefaults]
  default_realm = REALM.TDP
  dns_lookup_realm = false
  ticket_lifetime = 24h
  renew_lifetime = 7d
  forwardable = true

[realms]
  REALM.TDP = {
    kdc = master-01.tdp
    admin_server = master-01.tdp
  }

[domain_realm]
  .tdp = REALM.TDP
```
