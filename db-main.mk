MAKEFILE := $(firstword $(MAKEFILE_LIST))
BRANCH := main
DBTYPE := boltdb
DBPATH := ~/.cache/vuls/vuls.db

.PHONY: db-build
db-build:
	vuls db init --dbtype ${DBTYPE} --dbpath ${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-alma-errata BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-alpine-secdb BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-fedora BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-oracle-linux BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-redhat-vex-rhel BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-rocky-errata BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-ubuntu-cve-tracker BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}

.PHONY: db-add
db-add: 
	vuls-data-update dotgit pull --dir . --checkout ${BRANCH} --restore ghcr.io/vulsio/vuls-data-db:${REPO}

	cat ghcr.io/vulsio/vuls-data-db/${REPO}/datasource.json | jq --arg hash $$(git -C ghcr.io/vulsio/vuls-data-db/${REPO} rev-parse HEAD) --arg date $$(git -C ghcr.io/vulsio/vuls-data-db/${REPO} show -s --format=%at | xargs -I{} date -d @{} --utc +%Y-%m-%dT%TZ) '.extracted.commit |= $$hash | .extracted.date |= $$date' > tmp
	mv tmp ghcr.io/vulsio/vuls-data-db/${REPO}/datasource.json
	vuls db add --dbtype ${DBTYPE} --dbpath ${DBPATH} ghcr.io/vulsio/vuls-data-db/${REPO}
	rm -rf ghcr.io
