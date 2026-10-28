# Real keys for the AWS overlay

The four `*.env` files here are gitignored and must exist before
`kubectl apply -k k8s/overlays/aws` will build. Create them **on the instance**,
over an SSM session, so the values never touch a laptop or this repository.

The dev values in `k8s/base` are committed to a public repository, so they are
worthless as credentials: anyone could forge a JWT with `SIGNING_KEY` or sign
up with `REGISTRATION_CODE`. The overlay's `secretGenerator` replaces each one
wholesale.

| File | Keys |
| --- | --- |
| `backend.env` | `SIGNING_KEY`, `SERVICE_KEY`, `REGISTRATION_CODE`, `EMBEDDER_KEY` |
| `chatbot.env` | `SIGNING_KEY`, `SERVICE_KEY` |
| `embedder.env` | `EMBEDDER_KEY` |
| `postgres.env` | `POSTGRES_PASSWORD` |

Three values appear in more than one file and **must match exactly**, or you
get 401s that look like a routing fault:

- `SIGNING_KEY` — the chatbot decodes the user's JWT that the backend issued.
- `SERVICE_KEY` — the shared service credential, which is how the backend knows
  a write is the assistant acting for a user rather than the user.
- `EMBEDDER_KEY` — compared with `hmac.compare_digest` on the sweeper's hop.

The backend also refuses to start if `SERVICE_KEY == SIGNING_KEY`.

Generating a consistent set:

```bash
cd k8s/overlays/aws/secrets

SIGNING=$(openssl rand -hex 32)
SERVICE=$(openssl rand -hex 32)
EMBED=$(openssl rand -hex 32)
REGCODE=$(openssl rand -hex 8)
# Hex, because this ends up inside DATABASE_URL and the composition is plain
# string substitution with no URL encoding.
PGPASS=$(openssl rand -hex 16)

printf 'SIGNING_KEY=%s\nSERVICE_KEY=%s\nREGISTRATION_CODE=%s\nEMBEDDER_KEY=%s\n' \
  "$SIGNING" "$SERVICE" "$REGCODE" "$EMBED" > backend.env
printf 'SIGNING_KEY=%s\nSERVICE_KEY=%s\n' "$SIGNING" "$SERVICE" > chatbot.env
printf 'EMBEDDER_KEY=%s\n' "$EMBED" > embedder.env
printf 'POSTGRES_PASSWORD=%s\n' "$PGPASS" > postgres.env
```

Do not quote the values. `kubectl` and kustomize both treat everything after
the `=` as literal, unlike Compose's `env_file`, so a quoted value arrives with
its quotes attached.

`POSTGRES_PASSWORD` is only read by `initdb` on the volume's first start.
Changing it later updates the Secret, and therefore `DATABASE_URL`, without
changing the password Postgres actually expects — so rotate it by recreating
the volume, or with `ALTER USER`.

The Anthropic key is **not** here. It has no manifest at all; create it
directly:

```bash
read -rs KEY
kubectl create secret generic duly-chatbot-anthropic -n duly \
  --from-literal=ANTHROPIC_API_KEY="$KEY" && unset KEY
```
