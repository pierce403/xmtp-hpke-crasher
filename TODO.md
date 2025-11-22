# TODO - Next Steps for HPKE Error Investigation

## Immediate Actions

- [ ] File upstream issue using template in `upstream_issue.md`
  - Repository: https://github.com/xmtp/xmtp-js/issues
  - Title: "HPKE Decryption Errors Are Silently Swallowed in Node.js Bindings"

## Deep Debugging (If Needed)

- [ ] Clone and build XMTP SDK locally
  - Clone `xmtp-js` repository
  - Clone `libxmtp` repository (Rust bindings)
  - Build locally with additional debug logging
  - Link to this project for testing

- [ ] Instrument Rust bindings
  - Add logging to `xmtp_mls::groups::welcome_sync`
  - Capture encryption keys and message metadata
  - Track decryption path through OpenMLS

- [ ] Create minimal OpenMLS reproduction
  - Isolate the HPKE error to pure OpenMLS
  - Test with known good/bad key material
  - Determine if issue is in XMTP or OpenMLS layer

## Investigation Questions

- [ ] Why are some messages decrypting successfully while others fail?
  - Is it timing-related?
  - Installation sync issues?
  - Key rotation problems?

- [ ] What triggers the stale installation state?
  - Client restarts?
  - Network interruptions?
  - Multiple device scenarios?

- [ ] Can we force-refresh installations to recover?
  - Test `client.revokeAllOtherInstallations()`
  - Test manual installation sync

## Workarounds to Test

- [ ] Implement auto-retry on HPKE errors
  - Detect error via debug logs
  - Trigger installation refresh
  - Retry message processing

- [ ] Monitor installation consistency
  - Periodic checks of installation IDs
  - Alert on installation mismatches
  - Auto-revoke stale installations

## Documentation Improvements

- [x] Document HPKE error in README
- [x] Create upstream issue template
- [ ] Add troubleshooting guide
- [ ] Document installation key lifecycle
- [ ] Create diagram of error propagation path

## Repository Improvements

- [ ] Add automated test for HPKE error detection
- [ ] Create GitHub Actions workflow
- [ ] Add more scenarios (multi-device, network issues)
- [ ] Performance benchmarks

## Questions for XMTP Team

1. Why swallow HPKE errors instead of emitting them?
2. What's the recommended way to handle stale installations?
3. Are there known scenarios that trigger this error?
4. Is there a way to force installation refresh?
5. Should applications implement retry logic?
