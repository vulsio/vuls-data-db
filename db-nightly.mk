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
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-oracle BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-redhat-vex-rhel BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-rocky-errata BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-ubuntu-cve-tracker BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}

.PHONY: db-add
db-add: 
	oras pull ghcr.io/vulsio/vuls-data-db:${REPO}
	tar -xf ${REPO}.tar.zst
	rm ${REPO}.tar.zst
	git -C ${REPO} switch ${BRANCH}
	git -C ${REPO} restore .

	cat ${REPO}/datasource.json | jq --arg hash $$(git -C ${REPO} rev-parse HEAD) --arg date $$(git -C ${REPO} show -s --format=%at | xargs -I{} date -d @{} --utc +%Y-%m-%dT%TZ) '.extracted.commit |= $$hash | .extracted.date |= $$date' > tmp
	mv tmp ${REPO}/datasource.json
	vuls db add --dbtype ${DBTYPE} --dbpath ${DBPATH} ${REPO}
	rm -rf ${REPO}
