#!/bin/bash

BRANCHES="master release-3.7 release-3.6 release-3.5 release-3.4 release-3.3"
WORK_DIR=/home/ndevos/autobuild/glusterfs
LAST=24
# target is configured in ~/.ssh/config
SSH_SERVER='nightly'
SSH_TARGET='nightly:glusterfs-autobuild/sources/'
PUB_URL='http://download.gluster.org/pub/gluster/glusterfs/nightly/sources'
COPR_URL='http://copr-be.cloud.fedoraproject.org/results/devos/'

MAX_RETRIES=5

for BRANCH in ${BRANCHES}; do
	# this is the 1st try for this branch
	TRY=0

	while [ ${TRY} -lt ${MAX_RETRIES} ]; do
		TRY=$[${TRY} + 1]

		/home/ndevos/bin/autobuild-copr.sh -H ${LAST} -b ${BRANCH} -d ${WORK_DIR} -s ${SSH_TARGET} -p ${PUB_URL} -w -S
		RET=$?
		if [ ${RET} -eq 1 ]; then
			echo "a fatal error occured"
			# continue with the next branch
			break
		elif [ ${RET} -eq 100 ]; then
			# scp to the SSH_TARGET failed, retry
			continue
		elif [ ${RET} -eq 200 ]; then
			# no COPR build triggered, no changes in the git repo
			break
		fi

		# all went fine, break the retry loop
		break
	done

	if [ ${RET} -ne 0 ]; then
		# an error occured, continue with the next branch
		continue
	fi

	VERSION="$(sed 's/.*-//' <<< ${BRANCH})"
	COPR='glusterfs'
	if [ "${VERSION}" != 'master' ]; then
		COPR="glusterfs-${VERSION}"
	fi
	ssh ${SSH_SERVER} "cd glusterfs-autobuild/${COPR} ; lftp -e 'mirror --delete-first --only-newer ; exit' '${COPR_URL}/${COPR}'"
done


