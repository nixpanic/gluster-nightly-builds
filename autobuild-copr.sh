#!/bin/bash
#
# Automatically build GlusterFS from the HEAD of a git branch in Fedora COPR.
#
# Fedora COPR is a service provided by the Fedora Project for building
# non-standard packages and providing repositories. Official Fedora packages
# should be build from the Fedora packaging infrastructire (dist-git) and build
# in Koji.
#
# Dependencies:
# - git: used to clone a git repository and checkout a branch
# - autotools: ./autogen.sh is run
# - rpmbuild: create a src.rpm from te 'make dist' tarball
# - mock: used for local testing, see the -l option
# - scp: copy the resulting SRPM to a given target
# - copr-cli: schedule a build on http://copr.fedoraproject.org/
# - ~/.config/copr: get your config from http://copr.fedoraproject.org/api/
#
# COPR repositories that need to be available:
# - glusterfs: master branch packages
# - glusterfs-3.5: release-3.5 packages
# - glusterfs-x.y: release-x.y packages
#
# Author: Niels de Vos <ndevos@redhat.com>
#

# if RUN_LOCAL is defined, mock will be used instead of copr-cli
#RUN_LOCAL=1

# local path for the checked-out git repository
#WORK_DIR=$(mktemp -t -d)

# set to 1 to remove the workdir on successful finish
REMOVE_WORK_DIR=0

# git repository to clone
GIT_REPO_URL='git://review.gluster.org/glusterfs'

# the git branch to build
GIT_BRANCH='master'
#GIT_BRANCH='release-3.5'
#GIT_BRANCH='release-3.4'

# check for changes in the last SINCE_HOURS hours, dont build if no changes
SINCE_HOURS=24

# target public server:/path to scp the SRPM to
#SCP_TARGET='devos@people.fedoraproject.org:public_html/glusterfs-autobuild'

# public URL for downloading the SRPM
#PUBLIC_URL='http://people.fedoraproject.org/~devos/glusterfs-autobuild'

function usage()
{
	echo "Usage: ${0} -d <WORKDIR> -r <GIT_REPO> -b <BRANCH> -s <SCP_TARGET> -p <PUB_URL> -l"
	echo ''
	echo '-d <WORKDIR>      Directory to place the git repository in (defaults to a tmp one)'
	echo "-r <GIT_REPO>     URL to the git repository to clone (default: ${GIT_REPO_URL})"
	echo "-b <BRANCH>       Branch to use for building (default: ${GIT_BRANCH})"
	echo "-H <HOURS>        Only build if there were changes in the last HOURS (default: ${SINCE_HOURS}, use 0 to force)"
	echo '-s <SCP_TARGET>   URL to scp the resulting SRPM to'
	echo '-p <PUB_URL>      Public URL where the SRPM can be found after scp'
	echo '-l                Run on the local system only, use mock instead of copr-cli'
	echo ''
}

function cleanup()
{
	[ "${REMOVE_WORK_DIR}" == "1" ] && rm -rf ${WORK_DIR}
}

trap cleanup EXIT

if [ ${#@} -eq 0 ]; then
	usage
	exit 1
fi

while getopts "d:b:r:H:s:p:l" OPT; do
	case ${OPT} in
		d)
			WORK_DIR="${OPTARG}"
			REMOVE_WORK_DIR=0
			;;
		r)
			GIT_REPO_URL="${OPTARG}"
			;;
		b)
			GIT_BRANCH="${OPTARG}"
			;;
		H)
			SINCE_HOURS="${OPTARG}"
			;;
		s)
			SCP_TARGET="${OPTARG}"
			;;
		p)
			PUBLIC_URL="${OPTARG}"
			;;
		l)
			RUN_LOCAL=1
			;;
		*)
			usage
			exit 1
			;;
	esac
done

# check parameters
if [ -z "${WORK_DIR}" ]; then
	WORK_DIR=$(mktemp -t -d)
	REMOVE_WORK_DIR=1
fi
if [ -z "${GIT_REPO_URL}" ]; then
	echo "Error: GIT_REPO is not set"
	exit 1
elif [ -z "${GIT_BRANCH}" ]; then
	echo "Error: GIT_BRANCH is not set"
	exit 1
elif [ -z "${SINCE_HOURS}" ]; then
	echo "Error: HOURS is not set"
	exit 1
elif [ -z "${RUN_LOCAL}" ]; then
	if [ -z "${SCP_TARGET}" ]; then
		echo "Error: SCP_TARGET is not set"
		exit 1
	elif [ -z "${PUBLIC_URL}" ]; then
		echo "Error: PUBLIC_URL is not set"
		exit 1
	elif ! copr-cli list > /dev/null; then
		echo "Error: copr-cli is not working"
		if [ ! -e ~/.config/copr ]; then
			echo "Missing ~/.config/copr, see http://copr.fedoraproject.org/api/"
		fi
		exit 1
	fi
fi

# abort on an error
set -e

[ -d "${WORK_DIR}" ] || mkdir -p "${WORK_DIR}"
if [ ! -d "${WORK_DIR}/.git" ]; then
	git clone -q "${GIT_REPO_URL}" "${WORK_DIR}"
fi

pushd ${WORK_DIR}

# fetch the current status
git fetch -q -f origin

# reset the branch to checkout
if git log -1 autobuild/${GIT_BRANCH} > /dev/null; then
	# branch exists already
	git checkout -q autobuild/${GIT_BRANCH}
	git reset --hard origin/${GIT_BRANCH}
else
	git checkout -q -f -t -b autobuild/${GIT_BRANCH} origin/${GIT_BRANCH}
fi
git clean -f -d

# generate a version based on branch.date.last-commit-hash
if [ ${GIT_BRANCH} = 'master' ]; then
	GIT_VERSION=''
else
	GIT_VERSION="$(sed 's/.*-//' <<< ${GIT_BRANCH})."
fi

GIT_HASH="$(git log -1 --format=%h)"
VERSION="${GIT_VERSION}$(date +%Y%m%d).${GIT_HASH}"

if [ $(git shortlog --since="${SINCE_HOURS} hours" | wc -l) -eq 0 ]; then
	echo "There have been no changes since ${SINCE_HOURS} hours, no need to build"
	exit 0
fi

# tag the current commit for reference
if ! git tag "autobuild/${VERSION}"; then
	# this tag already exists, do not build again
	echo "${VERSION} has been build already, remove the tag 'autobuild/${VERSION}' to retry"
	exit 1
fi

# replace the default version by our autobuild one
sed -i "s/^AC_INIT.*/AC_INIT([glusterfs],[${VERSION}],[gluster-devel@nongnu.org])/" configure.ac

# Add a note to the ChangeLog (generated with 'make dist')
git commit -q -n --author='Autobuild <gluster-devel@nongnu.org>' \
	-m "autobuild: set version to ${VERSION}" configure.ac

# generate the tar.gz archive
./autogen.sh
./configure
rm -f *.tar.gz
make dist

# build the SRPM
rm -f *.src.rpm
SRPM=$(rpmbuild --define 'dist .autobuild' --define "_srcrpmdir ${PWD}" \
	-ts glusterfs-${VERSION}.tar.gz | cut -d' ' -f 2)

if [ -n "${RUN_LOCAL}" ]; then
	mock ${SRPM}
else
	# copy to a public reachable server
	scp ${SRPM} "${SCP_TARGET}"

	# trigger the COPR build for this new RPM
	URL="${PUBLIC_URL}/$(basename ${SRPM})"

	if [ -n "${GIT_VERSION}" ]
	then
		COPR_VERSION="-${GIT_VERSION}"
	fi

	COPR=glusterfs${COPR_VERSION}

	copr-cli build --nowait NOWAIT ${COPR} ${URL}
fi

popd # "${WORK_DIR}"

exit 0

