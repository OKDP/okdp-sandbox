# Changelog

## [0.5.0](https://github.com/OKDP/okdp-sandbox/compare/v0.4.0...v0.5.0) (2026-01-27)


### Features

* add Jupyter/PySpark integration ([5be3df9](https://github.com/OKDP/okdp-sandbox/commit/5be3df97256e77dd9fe465b3231c0317a40d825f))
* **context:** allow global proxy settings configuration (HTTP_PROXY, HTTPS_PROXY and NO_PROXY) ([104c77f](https://github.com/OKDP/okdp-sandbox/commit/104c77f3554c7848407d6999ccbe5aa2f723eeee))
* **data-catalog:** add hive-metastore package ([5b892fd](https://github.com/OKDP/okdp-sandbox/commit/5b892fd37250562bc4602b640bb17f86fd349e2e))
* **database:** add CNPG PostgreSQL operator as system service for sandbox database provisioning ([c0b8717](https://github.com/OKDP/okdp-sandbox/commit/c0b87176952e6c26ff00a22837b74435cec00ca3))
* **database:** add package to provision predefined local sandbox postgress databases for the services ([ff5e429](https://github.com/OKDP/okdp-sandbox/commit/ff5e42981af47465954f9f6f109ccd9abab5065b))
* **default-context:** add seaweedfs ([fff5ce2](https://github.com/OKDP/okdp-sandbox/commit/fff5ce295c23e27638de6681262f874e0a5c6314))
* **examples:** add okdp examples package ([1a82cdd](https://github.com/OKDP/okdp-sandbox/commit/1a82cddbc3a74ff9940413ce277f5ac07593f2f4))
* extend spark history with spark web proxy ([e3ff968](https://github.com/OKDP/okdp-sandbox/commit/e3ff968956e4e890c5578fe7b43deb13ed22da16))
* increase timeout to 10 minutes for all package deployments ([d462303](https://github.com/OKDP/okdp-sandbox/commit/d462303dbb5c58cfc1b3c196bc887747096b8808))
* **jupyterhub:** use provisioned secrets, stable ingress endpoints, and OKDP examples welcome page ([d6e9365](https://github.com/OKDP/okdp-sandbox/commit/d6e9365af570145ebbb75d07bd59b56b632859e1))
* **packages:** add seaweedfs ([e82606f](https://github.com/OKDP/okdp-sandbox/commit/e82606f135bb3cfa3df9a6cd17f266f16a2d28ee))
* **seaweedfs:** add licence ([2552e6c](https://github.com/OKDP/okdp-sandbox/commit/2552e6c4fd6f64bbec22f7fa6f2dc0ea4da067b6))
* **seaweedfs:** improve ocp-oauth-htpasswd and incorporate labels ([855d10d](https://github.com/OKDP/okdp-sandbox/commit/855d10d8eb96c1d35e32f05827d7ee42ea02c3e7))
* **seaweedfs:** set version for htpasswd and kubectl containers in ocp-oauth-htpasswd ([0b79aab](https://github.com/OKDP/okdp-sandbox/commit/0b79aab54401f8fa8397b01a8eee01bd2d4c2cbc))
* **secrets:** add local secrets provider package to bootstrap sandbox services (compatible with future external-secrets) ([edcfa29](https://github.com/OKDP/okdp-sandbox/commit/edcfa2934894fc6869c2970cddd9b83c85d6522a))
* **secrets:** add secret for seaweedfs database ([821ddc4](https://github.com/OKDP/okdp-sandbox/commit/821ddc4e338aff67eee1c9ca7b73b61e6d1e0179))
* **spark-history-server:** use provisioned secrets, stable ingress endpoints ([534c2fe](https://github.com/OKDP/okdp-sandbox/commit/534c2fe1f0f1fccc53301c02a5da735970fa6177))
* **storage:** pre-provision service credentials, stable ingress endpoints, and HMS warehouse bucket ([22fd4d2](https://github.com/OKDP/okdp-sandbox/commit/22fd4d2ed6189087ba893114ed9d515fcddc5760))
* **superset:** upgrade to 5.0.0 version ([516c957](https://github.com/OKDP/okdp-sandbox/commit/516c957bb0dc9fe8f474fc4d783ddc111c42cce5))
* **superset:** use provisioned DB/secrets, stable ingress endpoints, and configurable load_examples ([7f8dfb5](https://github.com/OKDP/okdp-sandbox/commit/7f8dfb51fafedbc5abb3af784047d2a75e6aceaf))
* **trino:** add hive-metastore catalog, use pre-provisioned secrets, and fixed ingress endpoints ([e29e4a2](https://github.com/OKDP/okdp-sandbox/commit/e29e4a272bd611cbc623a28703ecc873bc82be0f))
* **trino:** expose worker CPU and memory sizing parameters in UI ([b3a6edf](https://github.com/OKDP/okdp-sandbox/commit/b3a6edf3cb62d20118c5918b364146f2a6d44bdc))


### Bug Fixes

* allow DNS domain (e.g. okdp.sandbox) to be overridden from context ([4a7446c](https://github.com/OKDP/okdp-sandbox/commit/4a7446c1d0d28781a86557e1fdfff860a50ee193))
* **cert-manager:** extend webhook configuration for certificate validity duration ([29071a8](https://github.com/OKDP/okdp-sandbox/commit/29071a82a05634a445a51530dcac69dbc566f82d))
* **coredns:** update CoreDNS job and fix RBAC permissions ([631cbf8](https://github.com/OKDP/okdp-sandbox/commit/631cbf8471e383513bfac3e23db9c12c40c9bc97))
* dnsmasq permision denied ([66b788e](https://github.com/OKDP/okdp-sandbox/commit/66b788ea088070ab9e50bd2c99eb76b9fb30c1f2))
* externalize the configuration to the KuboCD default context ([3ecb0ce](https://github.com/OKDP/okdp-sandbox/commit/3ecb0cee1aa1fd8c2ec84f87ab78eb9b6d6a908c))
* **jupyterhub:** increase singleuser.startTimeout to 600 (300) ([2179bd7](https://github.com/OKDP/okdp-sandbox/commit/2179bd733f39fd7e959f73ed18a2219256b0feb5))
* **jupyterhub:** increase singleuser.startTimeout to 600 (300) ([59b10b6](https://github.com/OKDP/okdp-sandbox/commit/59b10b6ce42b00b824e5317aa4bf3b0877c46278))
* **jupyterhub:** use multi-arch image ([f59ed88](https://github.com/OKDP/okdp-sandbox/commit/f59ed881f2660de33a83a4c4f1b705bab3fbc989))
* **jupyterhub:** use multi-arch image ([8f61f66](https://github.com/OKDP/okdp-sandbox/commit/8f61f66fc89d8281c14d759f35958087d174ea08)), closes [#10](https://github.com/OKDP/okdp-sandbox/issues/10)
* **keycloak:** connect Keycloak to provisioned local Postgres DB instead of the embedded helm chart DB ([d680fce](https://github.com/OKDP/okdp-sandbox/commit/d680fce1a226bcd134111d50081be0fbcda723a8))
* **okdp-ui:** add trino logo and description ([473cb01](https://github.com/OKDP/okdp-sandbox/commit/473cb013f7af7809eb60a37ce07fd50d1da0f1f2))
* optimize keycloak deployment resources for sandbox ([641db29](https://github.com/OKDP/okdp-sandbox/commit/641db29b4d3c3e55575d8b7d23f59bfb5dec15f5))
* **seaweedfs:** correct job.yaml file in ocp-oauth-htpasswd ([37ef4e7](https://github.com/OKDP/okdp-sandbox/commit/37ef4e79aeff7be2146bd559445d7f06e1113312))
* **seaweedfs:** set auto configuration for volume limits ([169f3de](https://github.com/OKDP/okdp-sandbox/commit/169f3deef34bfaf3b90ef40362c782752fc038e6))
* **superset:** switch to okdp docker images (superset, dockerize and websocket) [#11](https://github.com/OKDP/okdp-sandbox/issues/11) ([240489f](https://github.com/OKDP/okdp-sandbox/commit/240489f20127608c9d95efc1cd2a4d78e8ab745f))
* update okdp-ui (drop IPv6) ([901ff4b](https://github.com/OKDP/okdp-sandbox/commit/901ff4bfa94ca19e44941a7df90f488f09346597))
* update repository path for spark-history-server helm chart ([909ffb1](https://github.com/OKDP/okdp-sandbox/commit/909ffb11c564ff3ec77e0ba5a5d714e4c94aeee0))
* update sandbox repository name ([2ed6fdb](https://github.com/OKDP/okdp-sandbox/commit/2ed6fdbbff6d21242e3967f7468b2fd4fcac3cba))
* **versioning:** make package versions SemVer-compliant for okdp-ui ([af6ab08](https://github.com/OKDP/okdp-sandbox/commit/af6ab08e1d2aa3afd00fc6a1ca0293f43d0e5f37))

## 0.4.0 (2025-10-06)


### Features

* increase timeout to 10 minutes for all package deployments ([d462303](https://github.com/OKDP/okdp-sandbox/commit/d462303dbb5c58cfc1b3c196bc887747096b8808))


### Bug Fixes

* **cert-manager:** extend webhook configuration for certificate validity duration ([29071a8](https://github.com/OKDP/okdp-sandbox/commit/29071a82a05634a445a51530dcac69dbc566f82d))
* **coredns:** update CoreDNS job and fix RBAC permissions ([631cbf8](https://github.com/OKDP/okdp-sandbox/commit/631cbf8471e383513bfac3e23db9c12c40c9bc97))
* **jupyterhub:** increase singleuser.startTimeout to 600 (300) ([2179bd7](https://github.com/OKDP/okdp-sandbox/commit/2179bd733f39fd7e959f73ed18a2219256b0feb5))
* **jupyterhub:** increase singleuser.startTimeout to 600 (300) ([59b10b6](https://github.com/OKDP/okdp-sandbox/commit/59b10b6ce42b00b824e5317aa4bf3b0877c46278))
* **jupyterhub:** use multi-arch image ([f59ed88](https://github.com/OKDP/okdp-sandbox/commit/f59ed881f2660de33a83a4c4f1b705bab3fbc989))
* **jupyterhub:** use multi-arch image ([8f61f66](https://github.com/OKDP/okdp-sandbox/commit/8f61f66fc89d8281c14d759f35958087d174ea08)), closes [#10](https://github.com/OKDP/okdp-sandbox/issues/10)
* **okdp-ui:** add trino logo and description ([473cb01](https://github.com/OKDP/okdp-sandbox/commit/473cb013f7af7809eb60a37ce07fd50d1da0f1f2))
* update repository path for spark-history-server helm chart ([909ffb1](https://github.com/OKDP/okdp-sandbox/commit/909ffb11c564ff3ec77e0ba5a5d714e4c94aeee0))
* update sandbox repository name ([2ed6fdb](https://github.com/OKDP/okdp-sandbox/commit/2ed6fdbbff6d21242e3967f7468b2fd4fcac3cba))
