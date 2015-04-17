Name:		dgo-nightly
Version:	1.0
Release:	0.3%{?dist}
BuildArch:	noarch
Summary:	Repository files for the download.gluster.org nightly builds

Group:		System Environment/Base
License:	GPLv2
URL:		http://download.gluster.org/pub/gluster/glusterfs/nightly/

%description
Repository files for the download.gluster.org nightly builds.

%package master
Summary:	Repository files for the download.gluster.org nightly builds (master branch)

%description master
Repository files for the download.gluster.org nightly builds (master branch).


%package 37
Summary:	Repository files for the download.gluster.org nightly builds (release-3.7)

%description 37
Repository files for the download.gluster.org nightly builds (release-3.7).


%package 36
Summary:	Repository files for the download.gluster.org nightly builds (release-3.6)

%description 36
Repository files for the download.gluster.org nightly builds (release-3.6).


%package 35
Summary:	Repository files for the download.gluster.org nightly builds (release-3.5)

%description 35
Repository files for the download.gluster.org nightly builds (release-3.5).


%package 34
Summary:	Repository files for the download.gluster.org nightly builds (release-3.4)

%description 34
Repository files for the download.gluster.org nightly builds (release-3.4).


%package 33
Summary:	Repository files for the download.gluster.org nightly builds (release-3.3)

%description 33
Repository files for the download.gluster.org nightly builds (release-3.3).


%prep


%build
%if 0%{?rhel:1}
DIST_NAME='EPEL-%{rhel}'
REPO_PATH='epel-%{rhel}-$basearch'
%else
DIST_NAME='Fedora %{fedora}'
REPO_PATH='fedora-%{fedora}-$basearch'
%endif

for VERSION in '' -3.7 -3.6 -3.5 -3.4 -3.3
do

cat << EOF > dgo-nightly${VERSION}.repo
[dgo-nightly${VERSION}]
name=Nightly Gluster builds for ${DIST_NAME} - \$basearch
baseurl=http://download.gluster.org/pub/gluster/glusterfs/nightly/glusterfs${VERSION}/${REPO_PATH}
failovermethod=priority
enabled=1
gpgcheck=0
EOF

done

%install
mkdir -p %{buildroot}/etc/yum.repos.d
for VERSION in '' -3.7 -3.6 -3.5 -3.4 -3.3
do
	install -m 0644 dgo-nightly${VERSION}.repo %{buildroot}/etc/yum.repos.d/dgo-nightly${VERSION}.repo
done


%files master
/etc/yum.repos.d/dgo-nightly.repo

%files 37
/etc/yum.repos.d/dgo-nightly-3.7.repo

%files 36
/etc/yum.repos.d/dgo-nightly-3.6.repo

%files 35
/etc/yum.repos.d/dgo-nightly-3.5.repo

%files 34
/etc/yum.repos.d/dgo-nightly-3.4.repo

%files 33
/etc/yum.repos.d/dgo-nightly-3.3.repo


%changelog
* Fri Apr 17 2015 Niels de Vos <ndevos@redhat.com>
- Add a sub-package for release-3.7.

* Thu Jul 31 2014 Niels de Vos <ndevos@redhat.com>
- Add a sub-package for release-3.6.

* Tue Apr 22 2014 Niels de Vos <ndevos@redhat.com>
- Initial packaging.
