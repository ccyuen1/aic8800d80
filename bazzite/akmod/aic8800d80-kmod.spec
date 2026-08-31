# AIC8800D80 akmod packaging for Bazzite/Fedora.
#
# The driver source is archived verbatim from SourceCommit.  Keep any local
# packaging work outside the driver directories and update SourceCommit only
# after the corresponding upstream revision has been reviewed.
# SourceCommit: 2895da26d8fe35bcec7483705d44c02c39e018fe

%if 0%{?fedora}
%global buildforkernels akmod
%global debug_package %{nil}
# Secure Boot is intentionally out of scope for this package's initial design.
%global _kmodtool_signmodules 0
%endif

%global kmod_name aic8800d80
# _firmwaredir is provided by some Fedora kernel packaging environments but
# not by a minimal akmodsbuild rebuild.  Use Fedora’s standard location then.
%{!?_firmwaredir:%global _firmwaredir %{_usr}/lib/firmware}

Name:           aic8800d80-kmod
Version:        1.0.0
Release:        1.git2895da2%{?dist}
Summary:        AIC8800D80 kernel-module source for akmods

License:        GPL-2.0-only
URL:            https://github.com/shenmintao/aic8800d80
Source0:        aic8800d80-%{version}.tar.gz

BuildRequires:  elfutils-libelf-devel
BuildRequires:  gcc
BuildRequires:  kmodtool
BuildRequires:  make
BuildRequires:  redhat-rpm-config
# Dependencies needed when akmods rebuilds this source RPM for a target kernel.
%global AkmodsBuildRequires elfutils-libelf-devel gcc make

# Generate akmod/meta packages for the source build, or kernel-specific kmod
# packages when akmodsbuild supplies the target kernel(s) through %%{kernels}.
%{expand:%(kmodtool --target %{_target_cpu} --kmodname %{kmod_name} %{?buildforkernels:--%{buildforkernels}} %{?kernels:--for-kernels "%{?kernels}"} 2>/dev/null)}

%description
Source package for building AIC8800D80 kernel modules with akmods.  The source
RPM remains kernel-independent; akmodsbuild generates a distinct kmod RPM for
each requested kernel version.

%package -n %{pkg_kmod_name}-common
Summary:        Firmware and integration files for AIC8800D80 kernel modules
Requires:       /usr/bin/eject
Requires:       usb_modeswitch

%description -n %{pkg_kmod_name}-common
Firmware, udev mode-switch rules, and usb_modeswitch configuration used by the
AIC8800D80 driver.  This package has no kernel-version dependency.

%prep
# Emit the generated package definitions to the build log for diagnostics.
kmodtool --target %{_target_cpu} --kmodname %{kmod_name} %{?buildforkernels:--%{buildforkernels}} %{?kernels:--for-kernels "%{?kernels}"} 2>/dev/null
%autosetup -n aic8800d80-%{version}

# Separate build directories are necessary if one source RPM is rebuilt for
# multiple target kernels in one akmodsbuild invocation.
for kernel_version in %{?kernel_versions}; do
    cp -a drivers/aic8800 _kmod_build_${kernel_version%%___*}
done

%build
for kernel_version in %{?kernel_versions}; do
    %{__make} %{?_smp_mflags} -C "${kernel_version##*___}" \
        M="%{_builddir}/aic8800d80-%{version}/_kmod_build_${kernel_version%%___*}" modules
done

%install
for kernel_version in %{?kernel_versions}; do
    install -d "%{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}"
    install -pm 0644 \
        _kmod_build_${kernel_version%%___*}/aic8800_fdrv/aic8800_fdrv.ko \
        _kmod_build_${kernel_version%%___*}/aic_load_fw/aic_load_fw.ko \
        _kmod_build_${kernel_version%%___*}/aic_zlp_quirk/aic_zlp_quirk.ko \
        "%{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}"
done

install -Dpm 0644 aic.rules \
    "%{buildroot}%{_udevrulesdir}/90-aic8800-mode-switch.rules"
install -Dpm 0644 usb_modeswitch/1111_1111 \
    "%{buildroot}%{_sysconfdir}/usb_modeswitch.d/1111:1111"
install -d "%{buildroot}%{_firmwaredir}"
cp -a fw/aic8800* "%{buildroot}%{_firmwaredir}/"

%{?akmod_install}

%files -n %{pkg_kmod_name}-common
%{_firmwaredir}/aic8800*
%{_udevrulesdir}/90-aic8800-mode-switch.rules
%config(noreplace) %{_sysconfdir}/usb_modeswitch.d/1111:1111

%changelog
* Sun Aug 30 2026 AIC8800 Bazzite akmod packaging contributors - 1.0.0-1.git2895da2
- Initial packaging-only akmod implementation.
