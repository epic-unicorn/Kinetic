#!/bin/sh
# setup-couch.sh
# Runs inside the couch_init container after CouchDB passes its health check.
# - Completes single-node cluster setup
# - Creates system databases (_users, _replicator)
# - Creates the kinetic_family application database
set -e

BASE="http://${COUCHDB_USER}:${COUCHDB_PASSWORD}@${COUCHDB_HOST:-couchdb}:${COUCHDB_PORT:-5984}"

echo "==> Completing single-node cluster setup..."
curl -sf -X POST "${BASE}/_cluster_setup" \
  -H "Content-Type: application/json" \
  -d '{"action":"enable_single_node","bind_address":"0.0.0.0","singlenode":true}' \
  -o /dev/null || true

echo "==> Ensuring system databases exist..."
for db in _users _replicator; do
  result=$(curl -sf -o /dev/null -w "%{http_code}" -X PUT "${BASE}/${db}")
  if [ "$result" = "201" ]; then
    echo "    Created ${db}"
  elif [ "$result" = "412" ]; then
    echo "    ${db} already exists"
  else
    echo "    Warning: PUT ${db} returned ${result}"
  fi
done

echo "==> Creating kinetic_family database..."
result=$(curl -sf -o /dev/null -w "%{http_code}" -X PUT "${BASE}/kinetic_family")
if [ "$result" = "201" ]; then
  echo "    Created kinetic_family"
elif [ "$result" = "412" ]; then
  echo "    kinetic_family already exists"
else
  echo "    Warning: PUT kinetic_family returned ${result}"
fi

echo "==> Hub setup complete."
