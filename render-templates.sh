#!/bin/bash

for f in $(ls templates/gcp/prereqs)
  do
    echo "envsubst < templates/gcp/prereqs/$f > prereqs/gcp/$f"
    envsubst < "templates/gcp/prereqs/$f" > "prereqs/gcp/$f"
done;

for f in $(ls templates/gcp/infra)
  do
    echo "envsubst < templates/gcp/infra/$f > infra/gcp/$f"
    envsubst < "templates/gcp/infra/$f" > "infra/gcp/$f"
done;

