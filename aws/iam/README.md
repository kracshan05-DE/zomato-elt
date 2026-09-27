# AWS IAM — S3 ↔ Snowflake trust chain

This project connects Snowflake to S3 using a **storage integration** — an IAM
role that Snowflake temporarily assumes, rather than a long-lived access key
embedded in Snowflake. If this integration were ever compromised, revoking it
kills access immediately; there is no key to rotate.

## Why role-based, not access keys

| Approach | Where the secret lives | Blast radius if leaked |
|---|---|---|
| Access key on external stage | Embedded in Snowflake SQL/metadata | Full S3 access, indefinitely, until manually rotated |
| **Storage integration (this project)** | Nowhere — Snowflake assumes a role via STS | Revoke the trust relationship, access dies instantly |

## Setup order (must be followed in sequence)

1. **Create the IAM policy** — [`s3-read-policy.json`](s3-read-policy.json).
   Read-only (`GetObject`, `ListBucket`), scoped to the `raw/` prefix only.
   Snowflake never needs write access to the raw zone.

2. **Create the IAM role** with a **placeholder** trust policy —
   [`snowflake-role-trust-policy-initial.json`](snowflake-role-trust-policy-initial.json).
   Attach the policy from step 1. Name it (this project uses
   `yt-snowflake-s3-role`). Copy the role's ARN.

3. **Create the Snowflake storage integration** — see
   [`snowflake/02_storage_integration.sql`](../../snowflake/02_storage_integration.sql) —
   passing the role ARN from step 2.

4. **Run `DESC INTEGRATION`** and copy two values:
   - `STORAGE_AWS_IAM_USER_ARN` — Snowflake's own IAM user identity
   - `STORAGE_AWS_EXTERNAL_ID` — a confused-deputy-attack guard

5. **Update the role's trust policy** with those two real values —
   [`snowflake-role-trust-policy-final.json`](snowflake-role-trust-policy-final.json).

## Two hard-won lessons

- The trust policy's `Principal` must be Snowflake's **IAM user ARN**
  (from step 4), not `:root` — using `:root` after the final trust update
  means any principal in Snowflake's AWS account could assume the role, not
  just Snowflake's own service identity for this integration.
- **Never re-run `CREATE OR REPLACE STORAGE INTEGRATION`** after step 5 —
  it regenerates the external ID, silently breaking the trust relationship
  until you redo steps 4–5.

## Common error and fix

```
User: arn:aws:sts::<acct>:assumed-role/yt-snowflake-s3-role/snowflake is not
authorized to perform: s3:ListBucket on resource: "arn:aws:s3:::<bucket>"
```

This means the policy only grants object-level actions (`GetObject`) on
`bucket/raw/*`, but `ListBucket` is a **bucket-level** action and must target
the bucket ARN itself (`arn:aws:s3:::<bucket>`, no trailing path), scoped
down with an `s3:prefix` condition instead. See `s3-read-policy.json` for
the corrected two-statement shape.
