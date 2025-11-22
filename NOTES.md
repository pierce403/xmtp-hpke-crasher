# XMTP HPKE Instrumentation Notes

## Happy-path receive with local libxmtp instrumentation

Receiver running with `./add-instrumentation.sh` + `./run.sh --recv`, using vendored `libxmtp` HPKE instrumentation. Successful delivery with HPKE unwrap logging:

```text
💓 [2025-11-22T13:03:32.207Z] Waiting for messages... (RSS: 334MB)
💓 [2025-11-22T13:03:37.213Z] Waiting for messages... (RSS: 334MB)
💓 [2025-11-22T13:03:42.217Z] Waiting for messages... (RSS: 291MB)
💓 [2025-11-22T13:03:47.222Z] Waiting for messages... (RSS: 291MB)
{"timestamp":"2025-11-22T13:03:48.572855Z","level":"ERROR","message":"HPKE unwrap_welcome starting","wrapped_welcome_len":3941,"wrapped_welcome_metadata_len":21,"private_key_len":32,"wrapper_algorithm":"XWingMLKEM768Draft6","target":"xmtp_mls::groups::mls_ext::welcome_wrapper"}
📩 Receiver got message: heyoooo
💓 [2025-11-22T13:03:52.223Z] Waiting for messages... (RSS: 385MB)
💓 [2025-11-22T13:03:57.228Z] Waiting for messages... (RSS: 385MB)
```

