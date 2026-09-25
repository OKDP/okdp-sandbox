# Changelog

## [1.1.0](https://github.com/OKDP/okdp-sandbox/compare/v1.0.0...v1.1.0) (2026-09-25)


### Features

* **platform:** declare the console's client id for audience verification ([4ce3f64](https://github.com/OKDP/okdp-sandbox/commit/4ce3f643baa22b7379bbd6d3485214e753fd1309))


### Bug Fixes

* **platform:** trust the sandbox's self-signed issuer certificate ([b6edf48](https://github.com/OKDP/okdp-sandbox/commit/b6edf48133649173c60552f013d4e9a24eff21dc))

## [1.0.0](https://github.com/OKDP/okdp-sandbox/compare/v0.5.0...v1.0.0) (2026-09-11)


### ⚠ BREAKING CHANGES

* **context:** nest the catalog services under their console section
* **contexts:** merge the context layers into a single platform Context

### Features

* added conventional commits ([b031a79](https://github.com/OKDP/okdp-sandbox/commit/b031a79c95a786e30191fe2b5a729b8996a7396b))
* **contracts:** declare the cluster contracts for typed platform connections ([2ede6d7](https://github.com/OKDP/okdp-sandbox/commit/2ede6d799f9507bcf71cf1dd44f921f86e0a5c22))
* **control-plane:** deploy the Control Plane as two KuboCD Releases ([55b727e](https://github.com/OKDP/okdp-sandbox/commit/55b727e27191314e3cf6ff33507884eda6e17b71))
* **demo:** add the demo project as layers two and three ([626fa3d](https://github.com/OKDP/okdp-sandbox/commit/626fa3d484a8e77ddbfc31910416ed325713e7d3))
* **demo:** declare the hive catalogs as a list ([7632bb7](https://github.com/OKDP/okdp-sandbox/commit/7632bb7954530aec658b2496294eee2281600881))
* **demo:** declare the human principals of the Polaris realm ([4f05fc8](https://github.com/OKDP/okdp-sandbox/commit/4f05fc8c8aceefc9bfc94afbef9002b5c887601e))
* **demo:** map the platform roles onto the History Server ACLs ([78a6bd4](https://github.com/OKDP/okdp-sandbox/commit/78a6bd4325aac147b6d5b127d5c6814488a84fc2))
* **demo:** mount the lakehouse buckets in the JupyterHub file browser ([5456be7](https://github.com/OKDP/okdp-sandbox/commit/5456be79d842b92fe64bdd78bf3230f05c61ff51))
* **kubocd:** install the released KuboCD v0.3.2 with Flux ([acd37fd](https://github.com/OKDP/okdp-sandbox/commit/acd37fde169f4552ab420d3f453d8cbfcca4edd2))
* **optional:** offer storage, vault and kubauth as optional components ([13cb049](https://github.com/OKDP/okdp-sandbox/commit/13cb0499855075031ff55458f8487491075eaec8))
* **packages:** move every pin to the published package versions ([ea08594](https://github.com/OKDP/okdp-sandbox/commit/ea08594e1504383f36a009ffb7b8af372f1a3a77))
* **packages:** update platform context versions to latest published version ([806b6cc](https://github.com/OKDP/okdp-sandbox/commit/806b6cc2d1a7ab0d39f15dbbf767f0b2e25e1b73))
* **releases:** point the infrastructure Releases at the reworked packages ([a807186](https://github.com/OKDP/okdp-sandbox/commit/a8071864d72338a9299b10006d375723c036052e))
* restore the cluster deployment layer under clusters/sandbox ([10a3f23](https://github.com/OKDP/okdp-sandbox/commit/10a3f23cd38a6a0de0867af6b8c8f0ef949734d4))
* updated readme to deployment scope only ([18f5e9c](https://github.com/OKDP/okdp-sandbox/commit/18f5e9cb342c2d8bd687911523a550d3601659cd))


### Bug Fixes

* adjust the keycloak and local secrets provider tag as it is the one sandbox dependencies will publish ([244b92d](https://github.com/OKDP/okdp-sandbox/commit/244b92d35ed7bba03876c760c8f2eda6e0cc86d9))
* **contexts:** replace SeaweedFS-specific storage with neutral storage settings ([#70](https://github.com/OKDP/okdp-sandbox/issues/70)) ([6650e73](https://github.com/OKDP/okdp-sandbox/commit/6650e737d3512548a6cec15c59a6bc9d6dfa89c9))
* **contexts:** scope defaultStorage endpoints to the release name ([#68](https://github.com/OKDP/okdp-sandbox/issues/68)) ([b3ab1da](https://github.com/OKDP/okdp-sandbox/commit/b3ab1dae2dd1ec0b4057b070e9addb76211105c4))
* **contexts:** use the renamed trino package in the catalog ([6920a4c](https://github.com/OKDP/okdp-sandbox/commit/6920a4ce1c84b54d99b7c0de555736747b2a893d))
* correct readme to reflect packages ownership ([a6cf128](https://github.com/OKDP/okdp-sandbox/commit/a6cf128bb8e46ede4e5e123fb72a800b6a797020))
* **demo:** bound the catalog job and reach Polaris in cluster ([c595c94](https://github.com/OKDP/okdp-sandbox/commit/c595c94d4a394397d31c0bfc77c2e88f8d69dd3b))
* **demo:** give SQL Lab back to the technical Superset profiles ([1a72c4d](https://github.com/OKDP/okdp-sandbox/commit/1a72c4ded6a088e93704285c634a88630f260025))
* **demo:** name the Polaris realm and the storage region in the PySpark catalogs ([a19e32d](https://github.com/OKDP/okdp-sandbox/commit/a19e32d1fdb72848fbea1666e8fca79bc6452337))
* **demo:** point the examples sync link at a branch that exists ([b425aa2](https://github.com/OKDP/okdp-sandbox/commit/b425aa22b290ed23c8775f4578c5432a2f3f578b))
* **demo:** read the object store endpoint from the s3 Connection ([1cf459e](https://github.com/OKDP/okdp-sandbox/commit/1cf459e7231dbe39bba99a47863298afacf8190b))
* derive the release parameters from the ingress suffix ([7528504](https://github.com/OKDP/okdp-sandbox/commit/752850428fc294547024820c0aafe7570046c41f))
* **keycloak:** add keycloak context variables for the dcr setting ([#81](https://github.com/OKDP/okdp-sandbox/issues/81)) ([00570d4](https://github.com/OKDP/okdp-sandbox/commit/00570d45511cb49057ee6991dc69969840bbec89))
* **keycloak:** allow the polaris-console redirect URI on any project ([e0fd48a](https://github.com/OKDP/okdp-sandbox/commit/e0fd48a128f7284eb7ffae3e45c16cc35d6f5137))
* **keycloak:** use a wildcard web origin so the console can call the token endpoint ([be0ddc0](https://github.com/OKDP/okdp-sandbox/commit/be0ddc0c7d744d913ed1e5fe35865c37c83c59e7))
* **packages:** updated jupytherhub version to 4.3.3-p07 ([54716ff](https://github.com/OKDP/okdp-sandbox/commit/54716fffcd027b54587b6e4b29cc939ac244be6a))
* point at current platform-packages registry without version prefix ([3ee6935](https://github.com/OKDP/okdp-sandbox/commit/3ee69353ec90610159fe5453b131b37d5e2ba7b5))
* point sandbox-dependencies owned releases to the corresponding OCI path ([ab1d807](https://github.com/OKDP/okdp-sandbox/commit/ab1d80700980ee4887a32e271c25b7a848a0f3ae))
* **project-demo:** sync the DAGs from the okdp-examples main branch ([1c857e7](https://github.com/OKDP/okdp-sandbox/commit/1c857e7f679e62787dac1b732c8ea52c21251bc6))
* send secrets with encoding ([2a8518d](https://github.com/OKDP/okdp-sandbox/commit/2a8518d7a499bbc04c0e1ec584a308feb4280fb0))
* Update clusters/sandbox/project-demo/50-services.yaml ([ab6feb1](https://github.com/OKDP/okdp-sandbox/commit/ab6feb108ae1a2e29e3705b273931d4966eaf408))
* update readme ([e9a3eba](https://github.com/OKDP/okdp-sandbox/commit/e9a3ebaa1ddd9c2c65ef9213fc4f171ff7c1c97c))
* updated the correct flux version to match with the readme pined version ([9b804ea](https://github.com/OKDP/okdp-sandbox/commit/9b804eae4e4e38f3ba5aed545742255904fb3646))


### Code Refactoring

* **context:** nest the catalog services under their console section ([e1dd213](https://github.com/OKDP/okdp-sandbox/commit/e1dd2134fbcf4e4df476556e0a030f4c121e59e5))
* **contexts:** merge the context layers into a single platform Context ([7a53a48](https://github.com/OKDP/okdp-sandbox/commit/7a53a480ac5361187daa54c5bbbce6e867ee1416))

## [0.5.0](https://github.com/OKDP/okdp-sandbox/compare/v0.4.0...v0.5.0) (2026-05-27)


### Features

* add Jupyter/PySpark integration ([5be3df9](https://github.com/OKDP/okdp-sandbox/commit/5be3df97256e77dd9fe465b3231c0317a40d825f))
* **airflow:** add OIDC auth support and harden package configuration ([3102465](https://github.com/OKDP/okdp-sandbox/commit/31024650b7d3f8de556b507c7beb80ebb4c3f959))
* **airflow:** point gitSync to okdp-examples repository ([9581b98](https://github.com/OKDP/okdp-sandbox/commit/9581b98e87df43046eab6441892ac1ee8d6e5973))
* **context:** allow global proxy settings configuration (HTTP_PROXY, HTTPS_PROXY and NO_PROXY) ([104c77f](https://github.com/OKDP/okdp-sandbox/commit/104c77f3554c7848407d6999ccbe5aa2f723eeee))
* **data-catalog:** add hive-metastore package ([5b892fd](https://github.com/OKDP/okdp-sandbox/commit/5b892fd37250562bc4602b640bb17f86fd349e2e))
* **database:** add CNPG PostgreSQL operator as system service for sandbox database provisioning ([c0b8717](https://github.com/OKDP/okdp-sandbox/commit/c0b87176952e6c26ff00a22837b74435cec00ca3))
* **database:** add package to provision predefined local sandbox postgress databases for the services ([ff5e429](https://github.com/OKDP/okdp-sandbox/commit/ff5e42981af47465954f9f6f109ccd9abab5065b))
* **default-context:** add seaweedfs ([fff5ce2](https://github.com/OKDP/okdp-sandbox/commit/fff5ce295c23e27638de6681262f874e0a5c6314))
* **examples:** add okdp examples package ([1a82cdd](https://github.com/OKDP/okdp-sandbox/commit/1a82cddbc3a74ff9940413ce277f5ac07593f2f4))
* extend spark history with spark web proxy ([e3ff968](https://github.com/OKDP/okdp-sandbox/commit/e3ff968956e4e890c5578fe7b43deb13ed22da16))
* increase timeout to 10 minutes for all package deployments ([d462303](https://github.com/OKDP/okdp-sandbox/commit/d462303dbb5c58cfc1b3c196bc887747096b8808))
* integrate Airflow ([162f490](https://github.com/OKDP/okdp-sandbox/commit/162f490daafc7a8b35ba1a7ee0c6a181e057ce3f))
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
* **trino:** add opa and opal for trino authorization ([6d1aca5](https://github.com/OKDP/okdp-sandbox/commit/6d1aca514fc5b6a1e8ad40d0e3ad2f17d11c4b5d))
* **trino:** expose worker CPU and memory sizing parameters in UI ([b3a6edf](https://github.com/OKDP/okdp-sandbox/commit/b3a6edf3cb62d20118c5918b364146f2a6d44bdc))


### Bug Fixes

* **airflow:** drop parasitic ACME annotation on web ingress ([abcc015](https://github.com/OKDP/okdp-sandbox/commit/abcc01528267f0f8c344cb462ce73137420c1df5))
* **airflow:** pass context proxy env to dags gitSync container ([6fb798d](https://github.com/OKDP/okdp-sandbox/commit/6fb798d76c4406a3274bb2c13a0d0debeebc7000))
* **airflow:** remove hardcoded credentials from usage message ([2f284a8](https://github.com/OKDP/okdp-sandbox/commit/2f284a8e9a21fd60df3c59bc72ae796504afd2b2))
* **airflow:** use metadataSecretName to fix migration job DB connection ([49d6c5e](https://github.com/OKDP/okdp-sandbox/commit/49d6c5e3fb9668455f6387aba8103f3edf8e9fdb))
* allow DNS domain (e.g. okdp.sandbox) to be overridden from context ([4a7446c](https://github.com/OKDP/okdp-sandbox/commit/4a7446c1d0d28781a86557e1fdfff860a50ee193))
* **cert-manager:** extend webhook configuration for certificate validity duration ([29071a8](https://github.com/OKDP/okdp-sandbox/commit/29071a82a05634a445a51530dcac69dbc566f82d))
* **coredns:** update CoreDNS job and fix RBAC permissions ([631cbf8](https://github.com/OKDP/okdp-sandbox/commit/631cbf8471e383513bfac3e23db9c12c40c9bc97))
* dnsmasq permision denied ([66b788e](https://github.com/OKDP/okdp-sandbox/commit/66b788ea088070ab9e50bd2c99eb76b9fb30c1f2))
* externalize the configuration to the KuboCD default context ([3ecb0ce](https://github.com/OKDP/okdp-sandbox/commit/3ecb0cee1aa1fd8c2ec84f87ab78eb9b6d6a908c))
* **ingress-nginx:** disable allowSnippetAnnotations to mitigate CVE-2026-42945 ([e66687c](https://github.com/OKDP/okdp-sandbox/commit/e66687cda857fa74d2fafe5f449bc67f80659c11))
* **jupyterhub:** increase singleuser.startTimeout to 600 (300) ([2179bd7](https://github.com/OKDP/okdp-sandbox/commit/2179bd733f39fd7e959f73ed18a2219256b0feb5))
* **jupyterhub:** increase singleuser.startTimeout to 600 (300) ([59b10b6](https://github.com/OKDP/okdp-sandbox/commit/59b10b6ce42b00b824e5317aa4bf3b0877c46278))
* **jupyterhub:** use multi-arch image ([f59ed88](https://github.com/OKDP/okdp-sandbox/commit/f59ed881f2660de33a83a4c4f1b705bab3fbc989))
* **jupyterhub:** use multi-arch image ([8f61f66](https://github.com/OKDP/okdp-sandbox/commit/8f61f66fc89d8281c14d759f35958087d174ea08)), closes [#10](https://github.com/OKDP/okdp-sandbox/issues/10)
* **keycloak:** connect Keycloak to provisioned local Postgres DB instead of the embedded helm chart DB ([d680fce](https://github.com/OKDP/okdp-sandbox/commit/d680fce1a226bcd134111d50081be0fbcda723a8))
* **keycloak:** increase ram ([4e9fdf8](https://github.com/OKDP/okdp-sandbox/commit/4e9fdf869d2869fd4ec809512082a978ed77e340))
* **keycloak:** increase ram ([3307b66](https://github.com/OKDP/okdp-sandbox/commit/3307b666aac7f95243cbd5d69dca7f52be20c819))
* **okdp-ui:** add trino logo and description ([473cb01](https://github.com/OKDP/okdp-sandbox/commit/473cb013f7af7809eb60a37ce07fd50d1da0f1f2))
* optimize keycloak deployment resources for sandbox ([641db29](https://github.com/OKDP/okdp-sandbox/commit/641db29b4d3c3e55575d8b7d23f59bfb5dec15f5))
* **seaweedfs:** correct job.yaml file in ocp-oauth-htpasswd ([37ef4e7](https://github.com/OKDP/okdp-sandbox/commit/37ef4e79aeff7be2146bd559445d7f06e1113312))
* **seaweedfs:** set auto configuration for volume limits ([169f3de](https://github.com/OKDP/okdp-sandbox/commit/169f3deef34bfaf3b90ef40362c782752fc038e6))
* Set PySpark notebook as default ([6bdb2cf](https://github.com/OKDP/okdp-sandbox/commit/6bdb2cf290af23c842832adb65c530320cf8395d))
* **spark-rbac:** bind spark-role to namespace ServiceAccount group ([7b98d2f](https://github.com/OKDP/okdp-sandbox/commit/7b98d2f6fc6b464b3cd0ceca76c102b4fb1a84bf))
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
