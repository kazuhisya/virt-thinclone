Summary: Virtualmachine ThinProvisioning Clone Tool
Name: virt-thinclone
Provides: virt-thinclone
Version: 0.0.3
Release: 1%{?dist}
License: GPLv2+
Group: Development/Libraries
Packager: Kazuhisa Hara <kazuhisya@gmail.com>
URL: https://github.com/kazuhisya/virt-thinclone
Source0: virt-thinclone-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch
Requires: ruby
Requires: ruby-libvirt
Requires: libvirt
Requires: libvirt-client
Requires: qemu-img
Requires: python-virtinst
Requires: guestfish

%description
Provides the Virtualmachine ThinProvisioning Clone Tool.


%prep
#%setup

%build
cd %{_sourcedir}
tar zxvf %{_sourcedir}/virt-thinclone-%{version}.tar.gz


%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/usr/local/bin $RPM_BUILD_ROOT/usr/share/doc/virt-thinclone-%{version}
cp -Rp %{_sourcedir}/virt-thinclone-%{version}/virt-thinclone $RPM_BUILD_ROOT/usr/local/bin
cp -Rp %{_sourcedir}/virt-thinclone-%{version}/README $RPM_BUILD_ROOT/usr/share/doc/virt-thinclone-%{version}


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
/usr/local/bin/virt-thinclone
/usr/share/doc/virt-thinclone-%{version}/README


%changelog
* Fri Jun 24 2011 Kazuhisa Hara <kazuhisya@gmail.com>
- Initial version
