# Typed parent/device gateway and small dispatcher

Local KR-004 boundaries now exist; no service is deployed or approved for real use.

- Goal: Test local device authorization and atomic parent control under extended OD-42.
- Context: [Design](../../docs/adr/0006-backend-and-sync.md).
- Constraints: No production exposure, pairing/login, push sender, sync engine or unapproved enforcement.
- Done when: KR-004 local acceptance has executed evidence with dependency stubs and unrun full-stack boundaries explicit.

- [Device gateway handler and HTTP/stub contract](device-gateway/README.md).
- [Actual PostgreSQL control transaction](CONTROL-TRANSACTION.md).
- [Reproducible local checks](../tests/README.md).
