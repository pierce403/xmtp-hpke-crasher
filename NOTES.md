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

## Sad-path receive (HPKE decryption failure, error swallowed)

Receiver running with instrumentation and a sender with stale keys. HPKE unwrap fails; bindings swallow the error and continue:

```text
💓 [2025-11-22T13:26:06.405Z] Waiting for messages... (RSS: 320MB)
💓 [2025-11-22T13:26:11.410Z] Waiting for messages... (RSS: 317MB)
{"timestamp":"2025-11-22T13:26:14.031801Z","level":"ERROR","message":"failed to create group from welcome=[sid(110837924):oid(11)] created at 1763817973: OpenMLS HPKE error: Decryption failed.","target":"xmtp_mls::groups::welcome_sync"}
{"timestamp":"2025-11-22T13:26:14.031847Z","level":"WARN","message":"[received] message error, swallowing to continue stream","inbox_id":"9b0adb484dbb75d3c1d696a9acfd683c58dbd81e46d591eeb45f86e81de9cbff","error":"Group(UnwrapWelcome(Hpke(DecryptionFailed)))","target":"bindings_node::conversations"}
💓 [2025-11-22T13:26:16.416Z] Waiting for messages... (RSS: 317MB)
💓 [2025-11-22T13:26:21.420Z] Waiting for messages... (RSS: 317MB)
```
