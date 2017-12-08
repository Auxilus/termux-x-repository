#!/data/data/com.termux/files/usr/bin/sh
##
##  APT repository builder
##
##  Packages for repository should be built with command:
##    fakeroot dpkg-deb --uniform-compression -z9 -Zxz -b {package dir} {package}.deb
##  or this script will show error on generating Packages/Packages.xz file
##

ARCHITECTURES="all aarch64 arm i686 x86_64"
CODENAME="termux"
SUITE="${CODENAME}"
COMPONENT="x-gui"
DESCRIPTION="a repository of X/GUI packages for Termux"
GPG_KEY="32545795"

SCRIPT_PATH=$(realpath "${0}")
REPO_PATH=$(dirname "${SCRIPT_PATH}")
RELEASE_PATH="${REPO_PATH}/dists/${CODENAME}/Release"
INRELEASE_PATH="${REPO_PATH}/dists/${CODENAME}/InRelease"

if ! rm -f "${RELEASE_PATH}" "${INRELEASE_PATH}"; then
    echo "[!] Cannot remove 'Release'."
    exit 1
fi

cat <<- EOF > "${RELEASE_PATH}"
Codename: ${CODENAME}
Version: 1
Architectures: ${ARCHITECTURES}
Description: ${DESCRIPTION}
Suite: ${SUITE}
Date: $(env TZ=UTC LANG=C date -Ru)
SHA256:
EOF

for arch in ${ARCHITECTURES}; do
    echo "[*] Processing repository for architecture '${arch}'"

    PACKAGE_DIR_PATH="${REPO_PATH}/dists/${CODENAME}/${COMPONENT}/binary-${arch}"

    if ! mkdir -p "${PACKAGE_DIR_PATH}" > /dev/null; then
        echo "[!] Cannot create path '${PACKAGE_DIR_PATH}'."
        exit 1
    fi

    (
        cd "${PACKAGE_DIR_PATH}" && {
            if ! rm -f "Packages" "Packages.xz" "Packages.gz" > /dev/null 2>&1; then
                echo "[!] Failed to remove file 'Packages'."
                exit 1
            fi

            if [ -z "$(find . -type f -iname \*.deb)" ]; then
                echo "[!] No *.deb files."
                exit 1
            fi

            echo
            for package in $(find . -type f -iname \*.deb | sort); do
                echo "    * adding '$(echo ${package} | cut -d/ -f2)'"
                ar -p "${package}" control.tar.xz | tar --to-stdout -xJf - ./control >> Packages
                FILENAME="${PACKAGE_DIR_PATH//"${REPO_PATH}/"}/${package//"./"}"
                SIZE=$(du -b "${package}" | awk '{ print $1 }')
                SHA256=$(sha256sum "${package}" | awk '{ print $1 }')
                echo "Filename: ${FILENAME}" >> Packages
                echo "Size: ${SIZE}" >> Packages
                echo "SHA256: ${SHA256}" >> Packages
                unset FILENAME
                unset SIZE
                unset SHA256
                echo >> Packages
            done

            if ! xz -9e -k Packages > /dev/null 2>&1; then
                echo "[!] Failed to compress file 'Packages'."
                exit 1
            fi

            echo " `sha256sum "Packages" | awk '{ print $1 }'` `du -b "Packages" | awk '{ print $1 }'` ${PACKAGE_DIR_PATH//"${REPO_PATH}/dists/${CODENAME}/"}/Packages" >> "${RELEASE_PATH}"
            echo " `sha256sum "Packages.xz" | awk '{ print $1 }'` `du -b "Packages.xz" | awk '{ print $1 }'` ${PACKAGE_DIR_PATH//"${REPO_PATH}/dists/${CODENAME}/"}/Packages.xz" >> "${RELEASE_PATH}"
        } || {
            echo "[!] Cannot cd to '${PACKAGE_DIR_PATH}'."
            exit 1
        }
    ) || exit 1
    echo
done

echo "[*] Signing repository"
cat "${RELEASE_PATH}" | gpg --clearsign --default-key "${GPG_KEY}" --digest-algo SHA512 -o "${INRELEASE_PATH}"
