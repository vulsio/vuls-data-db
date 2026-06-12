MAKEFILE := $(firstword $(MAKEFILE_LIST))
BRANCH := main
DBTYPE := boltdb
DBPATH := ~/.cache/vuls/vuls.db

.PHONY: db-build
db-build:
	vuls db init --dbtype ${DBTYPE} --dbpath ${DBPATH}
	# alma-errata: temporarily pinned to the last extracted commit that built a passing DB
	# (extracted anchor of vuls-nightly-db@sha256:06eb4252 — :nightly at 2026-05-27).
	# Upstream AlmaLinux 10 errata is mid-republish (large ALSA retirements); restore to
	# ${BRANCH} once the new baseline settles.
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-alma-errata BRANCH=e6b3fdedd7b245088c5409500c015a3e316140c6 DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-alpine-secdb BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-amazon BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-cisa-kev BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-debian-security-tracker-salsa BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-enisa-euvd-list BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-enisa-kev BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-exploit-exploitdb BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-exploit-github BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-exploit-inthewild BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-exploit-trickest BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-fedora-api BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-microsoft-bulletin BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-microsoft-cvrf BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-microsoft-msuc BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-microsoft-wsusscn2 BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-msf BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-nuclei-repository BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-nvd-feed-cve-v2 BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-oracle-linux BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-redhat-cve BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-redhat-vex-v1-rhel BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-rocky-errata BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-suse-oval BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-ubuntu-cve-tracker BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}
	$(MAKE) -f ${MAKEFILE} db-add REPO=vuls-data-extracted-vulncheck-kev BRANCH=${BRANCH} DBTYPE=${DBTYPE} DBPATH=${DBPATH}

.PHONY: db-add
db-add:
	vuls-data-update dotgit pull --dir . --checkout ${BRANCH} --restore ghcr.io/vulsio/vuls-data-db:${REPO}

	cat ghcr.io/vulsio/vuls-data-db/${REPO}/datasource.json | jq --arg hash $$(git -C ghcr.io/vulsio/vuls-data-db/${REPO} rev-parse HEAD) --arg date $$(git -C ghcr.io/vulsio/vuls-data-db/${REPO} show -s --format=%at | xargs -I{} date -d @{} --utc +%Y-%m-%dT%TZ) '.extracted.commit |= $$hash | .extracted.date |= $$date' > tmp
	mv tmp ghcr.io/vulsio/vuls-data-db/${REPO}/datasource.json
	vuls db add --dbtype ${DBTYPE} --dbpath ${DBPATH} ghcr.io/vulsio/vuls-data-db/${REPO}
	rm -rf ghcr.io
