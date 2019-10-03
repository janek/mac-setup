#!/bin/sh
# Quick Start

case "${SHELL}" in
  (*zsh) ;;
  (*) chsh -s "$(which zsh)"; exit 1 ;;
esac

# Initialize New Terminal

if test -z "${1}"; then
  osascript - "${0}" << EOF > /dev/null 2>&1
    on run { _this }
      tell app "Terminal" to do script "source " & quoted form of _this & " 0"
    end run
EOF
fi

# Define Function =ask=

ask () {
  osascript - "${1}" "${2}" "${3}" << EOF 2> /dev/null
    on run { _title, _action, _default }
      tell app "System Events" to return text returned of (display dialog _title with title _title buttons { "Cancel", _action } default answer _default)
    end run
EOF
}

# Define Function =ask2=

ask2 () {
  osascript - "$1" "$2" "$3" "$4" "$5" "$6" << EOF 2> /dev/null
on run { _text, _title, _cancel, _action, _default, _hidden }
  tell app "Terminal" to return text returned of (display dialog _text with title _title buttons { _cancel, _action } cancel button _cancel default button _action default answer _default hidden answer _hidden)
end run
EOF
}

# Define Function =p=

p () {
  printf "\n\033[1m\033[34m%s\033[0m\n\n" "${1}"
}

# Define Function =run=

run () {
  osascript - "${1}" "${2}" "${3}" << EOF 2> /dev/null
    on run { _title, _cancel, _action }
      tell app "Terminal" to return button returned of (display dialog _title with title _title buttons { _cancel, _action } cancel button 1 default button 2 giving up after 5)
    end run
EOF
}

# Define Function =init=

init () {
  init_sudo
  init_cache
  init_no_sleep
  init_hostname
  init_perms
  init_maskeep
  init_updates

  config_new_account
  config_rm_sudoers
}

if test "${1}" = 0; then
  printf "\n$(which init)\n"
fi

# Define Function =init_paths=

init_paths () {
  test -x "/usr/libexec/path_helper" && \
    eval $(/usr/libexec/path_helper -s)
}

# Eliminate Prompts for Password

init_sudo () {
  printf "%s\n" "%wheel ALL=(ALL) NOPASSWD: ALL" | \
  sudo tee "/etc/sudoers.d/wheel" > /dev/null && \
  sudo dscl /Local/Default append /Groups/wheel GroupMembership "$(whoami)"
}

# Select Installation Cache Location

init_cache () {
  grep -q "CACHES" "/etc/zshenv" 2> /dev/null || \
  a=$(osascript << EOF 2> /dev/null
    on run
      return text 1 through -2 of POSIX path of (choose folder with prompt "Select Installation Cache Location")
    end run
EOF
) && \
  test -d "${a}" || \
    a="${HOME}/Library/Caches/"

  grep -q "CACHES" "/etc/zshenv" 2> /dev/null || \
  printf "%s\n" \
    "export CACHES=\"${a}\"" \
    "export HOMEBREW_CACHE=\"${a}/brew\"" \
    "export BREWFILE=\"${a}/brew/Brewfile\"" | \
  sudo tee -a "/etc/zshenv" > /dev/null
  . "/etc/zshenv"

  if test -d "${CACHES}/upd"; then
    sudo chown -R "$(whoami)" "/Library/Updates"
    rsync -a --delay-updates \
      "${CACHES}/upd/" "/Library/Updates/"
  fi
}

# Set Defaults for Sleep

init_no_sleep () {
  sudo pmset -a sleep 0
  sudo pmset -a disksleep 0
}

# Set Hostname from DNS

init_hostname () {
  a=$(ask2 "Set Computer Name and Hostname" "Set Hostname" "Cancel" "Set Hostname" $(ruby -e "print '$(hostname -s)'.capitalize") "false")
  if test -n $a; then
    sudo scutil --set ComputerName $(ruby -e "print '$a'.capitalize")
    sudo scutil --set HostName $(ruby -e "print '$a'.downcase")
  fi
}

# Set Permissions on Install Destinations

_dest='/usr/local/bin
/Library/Desktop Pictures
/Library/ColorPickers
/Library/Fonts
/Library/Input Methods
/Library/PreferencePanes
/Library/QuickLook
/Library/Screen Savers
/Library/User Pictures'

init_perms () {
  printf "%s\n" "${_dest}" | \
  while IFS="$(printf '\t')" read d; do
    test -d "${d}" || sudo mkdir -p "${d}"
    sudo chgrp -R admin "${d}"
    sudo chmod -R g+w "${d}"
  done
}

# Install Developer Tools

init_devtools () {
  p="${HOMEBREW_CACHE}/Cask/Command Line Tools (macOS High Sierra version 10.13).pkg"
  i="com.apple.pkg.CLTools_SDK_macOS1013"

  if test -f "${p}"; then
    if ! pkgutil --pkg-info "${i}" > /dev/null 2>&1; then
      sudo installer -pkg "${p}" -target /
    fi
  else
    xcode-select --install
  fi
}

# Install Xcode

init_xcode () {
  if test -f ${HOMEBREW_CACHE}/Cask/xcode*.xip; then
    p "Installing Xcode"
    dest="${HOMEBREW_CACHE}/Cask/xcode"
    if ! test -d "$dest"; then
      pkgutil --expand ${HOMEBREW_CACHE}/Cask/xcode*.xip "$dest"
      curl --location --silent \
        "https://gist.githubusercontent.com/pudquick/ff412bcb29c9c1fa4b8d/raw/24b25538ea8df8d0634a2a6189aa581ccc6a5b4b/parse_pbzx2.py" | \
        python - "${dest}/Content"
      find "${dest}" -empty -name "*.xz" -type f -print0 | \
        xargs -0 -l 1 rm
      find "${dest}" -name "*.xz" -print0 | \
        xargs -0 -L 1 gunzip
      cat ${dest}/Content.part* > \
        ${dest}/Content.cpio
    fi
    cd /Applications && \
      sudo cpio -dimu --file=${dest}/Content.cpio
    for pkg in /Applications/Xcode*.app/Contents/Resources/Packages/*.pkg; do
      sudo installer -pkg "$pkg" -target /
    done
    x="$(find '/Applications' -maxdepth 1 -regex '.*/Xcode[^ ]*.app' -print -quit)"
    if test -n "${x}"; then
      sudo xcode-select -s "${x}"
      sudo xcodebuild -license accept
    fi
  fi
}

# Install macOS Updates

init_updates () {
  sudo softwareupdate --install --all
}

# Save Mac App Store Packages
# #+begin_example sh
# sudo lsof -c softwareupdated -F -r 2 | sed '/^n\//!d;/com.apple.SoftwareUpdate/!d;s/^n//'
# sudo lsof -c storedownloadd -F -r 2 | sed '/^n\//!d;/com.apple.appstore/!d;s/^n//'
# #+end_example

_maskeep_launchd='add	:KeepAlive	bool	false
add	:Label	string	com.github.ptb.maskeep
add	:ProcessType	string	Background
add	:Program	string	/usr/local/bin/maskeep
add	:RunAtLoad	bool	true
add	:StandardErrorPath	string	/dev/stderr
add	:StandardOutPath	string	/dev/stdout
add	:UserName	string	root
add	:WatchPaths	array	
add	:WatchPaths:0	string	$(sudo find '"'"'/private/var/folders'"'"' -name '"'"'com.apple.SoftwareUpdate'"'"' -type d -user _softwareupdate -print -quit 2> /dev/null)
add	:WatchPaths:1	string	$(sudo -u \\#501 -- sh -c '"'"'getconf DARWIN_USER_CACHE_DIR'"'"' 2> /dev/null)com.apple.appstore
add	:WatchPaths:2	string	$(sudo -u \\#502 -- sh -c '"'"'getconf DARWIN_USER_CACHE_DIR'"'"' 2> /dev/null)com.apple.appstore
add	:WatchPaths:3	string	$(sudo -u \\#503 -- sh -c '"'"'getconf DARWIN_USER_CACHE_DIR'"'"' 2> /dev/null)com.apple.appstore
add	:WatchPaths:4	string	/Library/Updates'

init_maskeep () {
  sudo softwareupdate --reset-ignored > /dev/null

  cat << EOF > "/usr/local/bin/maskeep"
#!/bin/sh

asdir="/Library/Caches/storedownloadd"
as1="\$(sudo -u \\#501 -- sh -c 'getconf DARWIN_USER_CACHE_DIR' 2> /dev/null)com.apple.appstore"
as2="\$(sudo -u \\#502 -- sh -c 'getconf DARWIN_USER_CACHE_DIR' 2> /dev/null)com.apple.appstore"
as3="\$(sudo -u \\#503 -- sh -c 'getconf DARWIN_USER_CACHE_DIR' 2> /dev/null)com.apple.appstore"
upd="/Library/Updates"
sudir="/Library/Caches/softwareupdated"
su="\$(sudo find '/private/var/folders' -name 'com.apple.SoftwareUpdate' -type d -user _softwareupdate 2> /dev/null)"

for i in 1 2 3 4 5; do
  mkdir -m a=rwxt -p "\$asdir"
  for as in "\$as1" "\$as2" "\$as3" "\$upd"; do
    test -d "\$as" && \
    find "\${as}" -type d -print | \\
    while read a; do
      b="\${asdir}/\$(basename \$a)"
      mkdir -p "\${b}"
      find "\${a}" -type f -print | \\
      while read c; do
        d="\$(basename \$c)"
        test -e "\${b}/\${d}" || \\
          ln "\${c}" "\${b}/\${d}" && \\
          chmod 666 "\${b}/\${d}"
      done
    done
  done

  mkdir -m a=rwxt -p "\${sudir}"
  find "\${su}" -name "*.tmp" -type f -print | \\
  while read a; do
    d="\$(basename \$a)"
    test -e "\${sudir}/\${d}.xar" ||
      ln "\${a}" "\${sudir}/\${d}.xar" && \\
      chmod 666 "\${sudir}/\${d}.xar"
  done

  sleep 1
done

exit 0
EOF

  chmod a+x "/usr/local/bin/maskeep"
  rehash

  config_launchd "/Library/LaunchDaemons/com.github.ptb.maskeep.plist" "$_maskeep_launchd" "sudo" ""
}

# Define Function =install=

install () {
  install_macos_sw
  install_node_sw
  install_perl_sw
  install_python_sw
  install_ruby_sw

  which config
}

# Install macOS Software with =brew=

install_macos_sw () {
  p "Installing macOS Software"
  install_paths
  install_brew
  install_brewfile_taps
  install_brewfile_brew_pkgs
  install_brewfile_cask_args
  install_brewfile_cask_pkgs
  install_brewfile_mas_apps

  x=$(find '/Applications' -maxdepth 1 -regex '.*/Xcode[^ ]*.app' -print -quit)
  if test -n "$x"; then
    sudo xcode-select -s "$x"
    sudo xcodebuild -license accept
  fi

  brew bundle --file="${BREWFILE}"

  x=$(find '/Applications' -maxdepth 1 -regex '.*/Xcode[^ ]*.app' -print -quit)
  if test -n "$x"; then
    sudo xcode-select -s "$x"
    sudo xcodebuild -license accept
  fi

  install_links
  sudo xattr -rd "com.apple.quarantine" "/Applications" > /dev/null 2>&1
  sudo chmod -R go=u-w "/Applications" > /dev/null 2>&1
}

# Add =/usr/local/bin/sbin= to Default Path

install_paths () {
  if ! grep -Fq "/usr/local/sbin" /etc/paths; then
    sudo sed -i "" -e "/\/usr\/sbin/{x;s/$/\/usr\/local\/sbin/;G;}" /etc/paths
  fi
}

# Install Homebrew Package Manager

install_brew () {
  if ! which brew > /dev/null; then
    ruby -e \
      "$(curl -Ls 'https://github.com/Homebrew/install/raw/master/install')" \
      < /dev/null > /dev/null 2>&1
  fi
  printf "" > "${BREWFILE}"
  brew analytics off
  brew update
  brew doctor
  brew tap "homebrew/bundle"
}

# Add Homebrew Taps to Brewfile

_taps='caskroom/cask
caskroom/fonts
caskroom/versions
homebrew/bundle
homebrew/command-not-found
homebrew/nginx
homebrew/php
homebrew/services
ptb/custom
railwaycat/emacsmacport'

install_brewfile_taps () {
  printf "%s\n" "${_taps}" | \
  while IFS="$(printf '\t')" read tap; do
    printf 'tap "%s"\n' "${tap}" >> "${BREWFILE}"
  done
  printf "\n" >> "${BREWFILE}"
}

# Add Homebrew Packages to Brewfile

_pkgs='aspell
bash
certbot
chromedriver
coreutils
dash
duti
e2fsprogs
fasd
fdupes
gawk
getmail
git
git-flow
git-lfs
gnu-sed
gnupg
gpac
httpie
hub
ievms
imagemagick
mas
mercurial
mp4v2
mtr
nmap
node
nodenv
openssl
p7zip
perl-build
pinentry-mac
plenv
pyenv
rbenv
rsync
selenium-server-standalone
shellcheck
sleepwatcher
sqlite
stow
syncthing
syncthing-inotify
tag
terminal-notifier
the_silver_searcher
trash
unrar
vcsh
vim
yarn
youtube-dl
zsh
zsh-syntax-highlighting
zsh-history-substring-search
homebrew/php/php71
ptb/custom/dovecot
ptb/custom/ffmpeg
sdl2
zimg
x265
webp
wavpack
libvorbis
libvidstab
two-lame
theora
tesseract
speex
libssh
libsoxr
snappy
schroedinger
rubberband
rtmpdump
opus
openh264
opencore-amr
libmodplug
libgsm
game-music-emu
fontconfig
fdk-aac
libcaca
libbs2b
libbluray
libass
chromaprint
ptb/custom/nginx-full'

install_brewfile_brew_pkgs () {
  printf "%s\n" "${_pkgs}" | \
  while IFS="$(printf '\t')" read pkg; do
    # printf 'brew "%s", args: [ "force-bottle" ]\n' "${pkg}" >> "${BREWFILE}"
    printf 'brew "%s"\n' "${pkg}" >> "${BREWFILE}"
  done
  printf "\n" >> "${BREWFILE}"
}

# Add Caskroom Options to Brewfile

_args='colorpickerdir	/Library/ColorPickers
fontdir	/Library/Fonts
input_methoddir	/Library/Input Methods
prefpanedir	/Library/PreferencePanes
qlplugindir	/Library/QuickLook
screen_saverdir	/Library/Screen Savers'

install_brewfile_cask_args () {
  printf 'cask_args \' >> "${BREWFILE}"
  printf "%s\n" "${_args}" | \
  while IFS="$(printf '\t')" read arg dir; do
    printf '\n  %s: "%s",' "${arg}" "${dir}" >> "${BREWFILE}"
  done
  sed -i "" -e '$ s/,/\
/' "${BREWFILE}"
}

# Add Homebrew Casks to Brewfile

_casks='java
xquartz
adium
alfred
arduino
atom
bbedit
betterzip
bitbar
caffeine
carbon-copy-cloner
charles
dash
dropbox
exifrenamer
find-empty-folders
firefox
github-desktop
gitup
google-chrome
hammerspoon
handbrake
hermes
imageoptim
inkscape
integrity
istat-menus
iterm2
jubler
little-snitch
machg
menubar-countdown
meteorologist
moom
mp4tools
musicbrainz-picard
namechanger
nvalt
nzbget
nzbvortex
openemu
opera
pacifist
platypus
plex-media-server
qlstephen
quitter
radarr
rescuetime
resilio-sync
scrivener
sizeup
sketch
sketchup
skitch
skype
slack
sonarr
sonarr-menu
sourcetree
steermouse
subler
sublime-text
the-unarchiver
time-sink
torbrowser
tower
unrarx
vimr
vlc
vmware-fusion
wireshark
xld
caskroom/fonts/font-inconsolata-lgc
caskroom/versions/transmit4
ptb/custom/adobe-creative-cloud-2014
ptb/custom/blankscreen
ptb/custom/composer
ptb/custom/enhanced-dictation
ptb/custom/ipmenulet
ptb/custom/pcalc-3
ptb/custom/sketchup-pro
ptb/custom/text-to-speech-alex
ptb/custom/text-to-speech-allison
ptb/custom/text-to-speech-samantha
ptb/custom/text-to-speech-tom
railwaycat/emacsmacport/emacs-mac-spacemacs-icon'

install_brewfile_cask_pkgs () {
  printf "%s\n" "${_casks}" | \
  while IFS="$(printf '\t')" read cask; do
    printf 'cask "%s"\n' "${cask}" >> "${BREWFILE}"
  done
  printf "\n" >> "${BREWFILE}"
}

# Add App Store Packages to Brewfile

_mas='1Password	443987910
Affinity Photo	824183456
Coffitivity	659901392
Duplicate Photos Fixer Pro	963642514
Growl	467939042
HardwareGrowler	475260933
I Love Stars	402642760
Icon Slate	439697913
Justnotes	511230166
Keynote	409183694
Metanota Pro	515250764
Numbers	409203825
Pages	409201541
WiFi Explorer	494803304
Xcode	497799835'

install_brewfile_mas_apps () {
  open "/Applications/App Store.app"
  run "Sign in to the App Store with your Apple ID" "Cancel" "OK"

  MASDIR="$(getconf DARWIN_USER_CACHE_DIR)com.apple.appstore"
  sudo chown -R "$(whoami)" "${MASDIR}"
  rsync -a --delay-updates \
    "${CACHES}/mas/" "${MASDIR}/"

  printf "%s\n" "${_mas}" | \
  while IFS="$(printf '\t')" read app id; do
    printf 'mas "%s", id: %s\n' "${app}" "${id}" >> "${BREWFILE}"
  done
}

# Link System Utilities to Applications

_links='/System/Library/CoreServices/Applications
/Applications/Xcode.app/Contents/Applications
/Applications/Xcode.app/Contents/Developer/Applications
/Applications/Xcode-beta.app/Contents/Applications
/Applications/Xcode-beta.app/Contents/Developer/Applications'

install_links () {
  printf "%s\n" "${_links}" | \
  while IFS="$(printf '\t')" read link; do
    find "${link}" -maxdepth 1 -name "*.app" -type d -print0 2> /dev/null | \
    xargs -0 -I {} -L 1 ln -s "{}" "/Applications" 2> /dev/null
  done
}

# Install Node.js with =nodenv=

_npm='eslint
eslint-config-cleanjs
eslint-plugin-better
eslint-plugin-fp
eslint-plugin-import
eslint-plugin-json
eslint-plugin-promise
eslint-plugin-standard
gatsby
json
sort-json'

install_node_sw () {
  if which nodenv > /dev/null; then
    NODENV_ROOT="/usr/local/node" && export NODENV_ROOT

    sudo mkdir -p "$NODENV_ROOT"
    sudo chown -R "$(whoami):admin" "$NODENV_ROOT"

    p "Installing Node.js with nodenv"
    git clone https://github.com/nodenv/node-build-update-defs.git \
      "$(nodenv root)"/plugins/node-build-update-defs
    nodenv update-version-defs > /dev/null

    nodenv install --skip-existing 8.7.0
    nodenv global 8.7.0

    grep -q "${NODENV_ROOT}" "/etc/paths" || \
    sudo sed -i "" -e "1i\\
${NODENV_ROOT}/shims
" "/etc/paths"

    init_paths
    rehash
  fi

  T=$(printf '\t')

  printf "%s\n" "$_npm" | \
  while IFS="$T" read pkg; do
    npm install --global "$pkg"
  done

  rehash
}

# Install Perl 5 with =plenv=

install_perl_sw () {
  if which plenv > /dev/null; then
    PLENV_ROOT="/usr/local/perl" && export PLENV_ROOT

    sudo mkdir -p "$PLENV_ROOT"
    sudo chown -R "$(whoami):admin" "$PLENV_ROOT"

    p "Installing Perl 5 with plenv"
    plenv install 5.26.0 > /dev/null 2>&1
    plenv global 5.26.0

    grep -q "${PLENV_ROOT}" "/etc/paths" || \
    sudo sed -i "" -e "1i\\
${PLENV_ROOT}/shims
" "/etc/paths"

    init_paths
    rehash
  fi
}

# Install Python with =pyenv=

install_python_sw () {
  if which pyenv > /dev/null; then
    CFLAGS="-I$(brew --prefix openssl)/include" && export CFLAGS
    LDFLAGS="-L$(brew --prefix openssl)/lib" && export LDFLAGS
    PYENV_ROOT="/usr/local/python" && export PYENV_ROOT

    sudo mkdir -p "$PYENV_ROOT"
    sudo chown -R "$(whoami):admin" "$PYENV_ROOT"

    p "Installing Python 2 with pyenv"
    pyenv install --skip-existing 2.7.13
    p "Installing Python 3 with pyenv"
    pyenv install --skip-existing 3.6.2
    pyenv global 2.7.13

    grep -q "${PYENV_ROOT}" "/etc/paths" || \
    sudo sed -i "" -e "1i\\
${PYENV_ROOT}/shims
" "/etc/paths"

    init_paths
    rehash

    pip install --upgrade "pip" "setuptools"

    # Reference: https://github.com/mdhiggins/sickbeard_mp4_automator
    pip install --upgrade "babelfish" "guessit<2" "qtfaststart" "requests" "stevedore==1.19.1" "subliminal<2"
    pip install --upgrade "requests-cache" "requests[security]"

    # Reference: https://github.com/pixelb/crudini
    pip install --upgrade "crudini"
  fi
}

# Install Ruby with =rbenv=

install_ruby_sw () {
  if which rbenv > /dev/null; then
    RBENV_ROOT="/usr/local/ruby" && export RBENV_ROOT

    sudo mkdir -p "$RBENV_ROOT"
    sudo chown -R "$(whoami):admin" "$RBENV_ROOT"

    p "Installing Ruby with rbenv"
    rbenv install --skip-existing 2.4.2
    rbenv global 2.4.2

    grep -q "${RBENV_ROOT}" "/etc/paths" || \
    sudo sed -i "" -e "1i\\
${RBENV_ROOT}/shims
" "/etc/paths"

    init_paths
    rehash

    printf "%s\n" \
      "gem: --no-document" | \
    tee "${HOME}/.gemrc" > /dev/null

    gem update --system > /dev/null

    trash "$(which rdoc)"
    trash "$(which ri)"
    gem update

    gem install bundler
  fi
}

# Define Function =config=

config () {
  config_admin_req
  config_bbedit
  config_certbot
  config_desktop
  config_dovecot
  config_emacs
  config_environment
  config_ipmenulet
  config_istatmenus
  config_nginx
  config_openssl
  config_sysprefs
  config_zsh
  config_guest

  which custom
}

# Define Function =config_defaults=

config_defaults () {
  printf "%s\n" "${1}" | \
  while IFS="$(printf '\t')" read domain key type value host; do
    ${2} defaults ${host} write ${domain} "${key}" ${type} "${value}"
  done
}

# Define Function =config_plist=

T="$(printf '\t')"

config_plist () {
  printf "%s\n" "$1" | \
  while IFS="$T" read command entry type value; do
    case "$value" in
      (\$*)
        $4 /usr/libexec/PlistBuddy "$2" \
          -c "$command '${3}${entry}' $type '$(eval echo \"$value\")'" 2> /dev/null ;;
      (*)
        $4 /usr/libexec/PlistBuddy "$2" \
          -c "$command '${3}${entry}' $type '$value'" 2> /dev/null ;;
    esac
  done
}

# Define Function =config_launchd=

config_launchd () {
  test -d "$(dirname $1)" || \
    $3 mkdir -p "$(dirname $1)"

  test -f "$1" && \
    $3 launchctl unload "$1" && \
    $3 rm -f "$1"

  config_plist "$2" "$1" "$4" "$3" && \
    $3 plutil -convert xml1 "$1" && \
    $3 launchctl load "$1"
}

# Mark Applications Requiring Administrator Account

_admin_req='Carbon Copy Cloner.app
Charles.app
Composer.app
Dropbox.app
iStat Menus.app
Moom.app
VMware Fusion.app
Wireshark.app'

config_admin_req () {
  printf "%s\n" "${_admin_req}" | \
  while IFS="$(printf '\t')" read app; do
    sudo tag -a "Red, admin" "/Applications/${app}"
  done
}

# Configure BBEdit

config_bbedit () {
  if test -d "/Applications/BBEdit.app"; then
    test -f "/usr/local/bin/bbdiff" || \
    ln /Applications/BBEdit.app/Contents/Helpers/bbdiff /usr/local/bin/bbdiff && \
    ln /Applications/BBEdit.app/Contents/Helpers/bbedit_tool /usr/local/bin/bbedit && \
    ln /Applications/BBEdit.app/Contents/Helpers/bbfind /usr/local/bin/bbfind && \
    ln /Applications/BBEdit.app/Contents/Helpers/bbresults /usr/local/bin/bbresults
  fi
}

# Configure Let’s Encrypt

config_certbot () {
  test -d "/etc/letsencrypt" || \
    sudo mkdir -p /etc/letsencrypt

  sudo tee "/etc/letsencrypt/cli.ini" << EOF > /dev/null
agree-tos = True
authenticator = standalone
eff-email = True
manual-public-ip-logging-ok = True
nginx-ctl = $(which nginx)
nginx-server-root = /usr/local/etc/nginx
preferred-challenges = tls-sni-01
keep-until-expiring = True
rsa-key-size = 4096
text = True
EOF

  if ! test -e "/etc/letsencrypt/.git"; then
    a=$(ask "Existing Let’s Encrypt Git Repository Path or URL?" "Clone Repository" "")
    test -n "$a" && \
    case "$a" in
      (/*)
        sudo tee "/etc/letsencrypt/.git" << EOF > /dev/null ;;
gitdir: $a
EOF
      (*)
        sudo git -C "/etc/letsencrypt" remote add origin "$a"
        sudo git -C "/etc/letsencrypt" fetch origin master ;;
    esac
    sudo git -C "/etc/letsencrypt" reset --hard
    sudo git checkout -f -b master HEAD
  fi

  sudo launchctl unload /Library/LaunchDaemons/org.nginx.nginx.plist 2> /dev/null
  sudo certbot renew

  while true; do
    test -n "$1" && server_name="$1" || \
      server_name="$(ask 'New SSL Server: Server Name?' 'Create Server' 'example.com')"
    test -n "$server_name" || break

    test -n "$2" && proxy_address="$2" || \
      proxy_address="$(ask "Proxy Address for $server_name?" 'Set Address' 'http://127.0.0.1:80')"

    sudo certbot certonly --domain $server_name

    key1="$(openssl x509 -pubkey < /etc/letsencrypt/live/$server_name/fullchain.pem | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64)"
    key2="$(curl -s https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem | openssl x509 -pubkey | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64)"
    key3="$(curl -s https://letsencrypt.org/certs/isrgrootx1.pem | openssl x509 -pubkey | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64)"

    pkp="$(printf "add_header Public-Key-Pins 'pin-sha256=\"%s\"; pin-sha256=\"%s\"; pin-sha256=\"%s\"; max-age=2592000;';\n" $key1 $key2 $key3)"

    cat << EOF > "/usr/local/etc/nginx/servers/$server_name.conf"
server {
  server_name $server_name;

  location / {
    proxy_pass $proxy_address;
  }

  ssl_certificate /etc/letsencrypt/live/$server_name/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$server_name/privkey.pem;
  ssl_trusted_certificate /etc/letsencrypt/live/$server_name/chain.pem;

  $pkp

  add_header Content-Security-Policy "upgrade-insecure-requests;";
  add_header Referrer-Policy "strict-origin";
  add_header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload" always;
  add_header X-Content-Type-Options nosniff;
  add_header X-Frame-Options DENY;
  add_header X-Robots-Tag none;
  add_header X-XSS-Protection "1; mode=block";

  listen 443 ssl http2;
  listen [::]:443 ssl http2;

  ssl_stapling on;
  ssl_stapling_verify on;

  # https://securityheaders.io/?q=https%3A%2F%2F$server_name&hide=on&followRedirects=on
  # https://www.ssllabs.com/ssltest/analyze.html?d=$server_name&hideResults=on&latest
}
EOF
    unset argv
  done

  sudo launchctl load /Library/LaunchDaemons/org.nginx.nginx.plist
}

# Configure Default Apps

config_default_apps () {
  true
}

# Configure Desktop Picture

config_desktop () {
  sudo rm -f "/Library/Caches/com.apple.desktop.admin.png"

  base64 -D << EOF > "/Library/Desktop Pictures/Solid Colors/Solid Black.png"
iVBORw0KGgoAAAANSUhEUgAAAIAAAACAAQAAAADrRVxmAAAAGElEQVR4AWOgMxgFo2AUjIJRMApGwSgAAAiAAAH3bJXBAAAAAElFTkSuQmCC
EOF
}

# Configure Dovecot

config_dovecot () {
  if which /usr/local/sbin/dovecot > /dev/null; then
    if ! run "Configure Dovecot Email Server?" "Configure Server" "Cancel"; then
      sudo tee "/usr/local/etc/dovecot/dovecot.conf" << EOF > /dev/null
auth_mechanisms = cram-md5
default_internal_user = _dovecot
default_login_user = _dovenull
log_path = /dev/stderr
mail_location = maildir:~/.mail:INBOX=~/.mail/Inbox:LAYOUT=fs
mail_plugins = zlib
maildir_copy_with_hardlinks = no
namespace {
  inbox = yes
  mailbox Drafts {
    auto = subscribe
    special_use = \Drafts
  }
  mailbox Junk {
    auto = subscribe
    special_use = \Junk
  }
  mailbox Sent {
    auto = subscribe
    special_use = \Sent
  }
  mailbox "Sent Messages" {
    special_use = \Sent
  }
  mailbox Trash {
    auto = subscribe
    special_use = \Trash
  }
  separator = .
  type = private
}
passdb {
  args = scheme=cram-md5 /usr/local/etc/dovecot/cram-md5.pwd
  driver = passwd-file

  # driver = pam

  # args = nopassword=y
  # driver = static
}
plugin {
  sieve = file:/Users/%u/.sieve
  sieve_plugins = sieve_extprograms
  zlib_save = bz2
  zlib_save_level = 9
}
protocols = imap
service imap-login {
  inet_listener imap {
    port = 0
  }
}
ssl = required
ssl_cipher_list = ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS:!AES128
ssl_dh_parameters_length = 4096
ssl_prefer_server_ciphers = yes
ssl_protocols = !SSLv2 !SSLv3
userdb {
  driver = passwd
}
protocol lda {
  mail_plugins = sieve zlib
}

# auth_debug = yes
# auth_debug_passwords = yes
# auth_verbose = yes
# auth_verbose_passwords = plain
# mail_debug = yes
# verbose_ssl = yes
EOF

      MAILADM="$(ask 'Email: Postmaster Email?' 'Set Email' "$(whoami)@$(hostname -f | cut -d. -f2-)")"
      MAILSVR="$(ask 'Email: Server Hostname for DNS?' 'Set Hostname' "$(hostname -f)")"
      sudo certbot certonly --domain $MAILSVR
      printf "%s\n" \
        "postmaster_address = '${MAILADM}'" \
        "ssl_cert = </etc/letsencrypt/live/$MAILSVR/fullchain.pem" \
        "ssl_key = </etc/letsencrypt/live/$MAILSVR/privkey.pem" | \
      sudo tee -a "/usr/local/etc/dovecot/dovecot.conf" > /dev/null

      if test ! -f "/usr/local/etc/dovecot/cram-md5.pwd"; then
        while true; do
          MAILUSR="$(ask 'New Email Account: User Name?' 'Create Account' "$(whoami)")"
          test -n "${MAILUSR}" || break
          doveadm pw | \
          sed -e "s/^/${MAILUSR}:/" | \
          sudo tee -a "/usr/local/etc/dovecot/cram-md5.pwd"
        done
        sudo chown _dovecot "/usr/local/etc/dovecot/cram-md5.pwd"
        sudo chmod go= "/usr/local/etc/dovecot/cram-md5.pwd"
      fi

      sudo tee "/etc/pam.d/dovecot" << EOF > /dev/null
auth	required	pam_opendirectory.so	try_first_pass
account	required	pam_nologin.so
account	required	pam_opendirectory.so
password	required	pam_opendirectory.so
EOF

      sudo brew services start dovecot

      cat << EOF > "/usr/local/bin/imaptimefix.py"
#!/usr/bin/env python

# Author: Zachary Cutlip <@zcutlip>
# http://shadow-file.blogspot.com/2012/06/parsing-email-and-fixing-timestamps-in.html
# Updated: Peter T Bosse II <@ptb>
# Purpose: A program to fix sorting of mail messages that have been POPed or
#          IMAPed in the wrong order. Compares time stamp sent and timestamp
#          received on an RFC822-formatted email message, and renames the
#          message file using the most recent timestamp that is no more than
#          24 hours after the date sent. Updates the file's atime/mtime with
#          the timestamp, as well. Does not modify the headers or contents of
#          the message.

from bz2 import BZ2File
from email import message_from_string
from email.utils import mktime_tz, parsedate_tz
from os import rename, utime, walk
from os.path import abspath, isdir, isfile, join
from re import compile, match
from sys import argv

if isdir(argv[1]):
  e = compile("([0-9]+)(\..*$)")

  for a, b, c in walk(argv[1]):
    for d in c:
      if e.match(d):
        f = message_from_string(BZ2File(join(a, d)).read())
        g = mktime_tz(parsedate_tz(f.get("Date")))

        h = 0
        for i in f.get_all("Received", []):
          j = i.split(";")[-1]
          if parsedate_tz(j):
            k = mktime_tz(parsedate_tz(j))
            if (k - g) > (60*60*24):
              continue

            h = k
          break

        if (h < 1):
          h = g

        l = e.match(d)

        if len(l.groups()) == 2:
          m = str(int(h)) + l.groups()[1]
          if not isfile(join(a, m)):
            rename(join(a, d), join(a, m))
          utime(join(a, m), (h, h))
EOF
      chmod +x /usr/local/bin/imaptimefix.py
    fi
  fi
}

# Configure Emacs

config_emacs () {
  test -f "/usr/local/bin/vi" || \
  cat << EOF > "/usr/local/bin/vi"
#!/bin/sh

if [ -e "/Applications/Emacs.app" ]; then
  t=()

  if [ \${#@} -ne 0 ]; then
    while IFS= read -r file; do
      [ ! -f "\$file" ] && t+=("\$file") && /usr/bin/touch "\$file"
      file=\$(echo \$(cd \$(dirname "\$file") && pwd -P)/\$(basename "\$file"))
      \$(/usr/bin/osascript <<-END
        if application "Emacs.app" is running then
          tell application id (id of application "Emacs.app") to open POSIX file "\$file"
        else
          tell application ((path to applications folder as text) & "Emacs.app")
            activate
            open POSIX file "\$file"
          end tell
        end if
END
        ) &  # Note: END on the previous line may be indented with tabs but not spaces
    done <<<"\$(printf '%s\n' "\$@")"
  fi

  if [ ! -z "\$t" ]; then
    \$(/bin/sleep 10; for file in "\${t[@]}"; do
      [ ! -s "\$file" ] && /bin/rm "\$file";
    done) &
  fi
else
  vim -No "\$@"
fi
EOF

  chmod a+x /usr/local/bin/vi
  rehash
}

# Configure Environment Variables

_environment_defaults='/Library/LaunchAgents/environment.user	KeepAlive	-bool	false	
/Library/LaunchAgents/environment.user	Label	-string	environment.user	
/Library/LaunchAgents/environment.user	ProcessType	-string	Background	
/Library/LaunchAgents/environment.user	Program	-string	/etc/environment.sh	
/Library/LaunchAgents/environment.user	RunAtLoad	-bool	true	
/Library/LaunchAgents/environment.user	WatchPaths	-array-add	/etc/environment.sh	
/Library/LaunchAgents/environment.user	WatchPaths	-array-add	/etc/paths	
/Library/LaunchAgents/environment.user	WatchPaths	-array-add	/etc/paths.d	
/Library/LaunchDaemons/environment	KeepAlive	-bool	false	
/Library/LaunchDaemons/environment	Label	-string	environment	
/Library/LaunchDaemons/environment	ProcessType	-string	Background	
/Library/LaunchDaemons/environment	Program	-string	/etc/environment.sh	
/Library/LaunchDaemons/environment	RunAtLoad	-bool	true	
/Library/LaunchDaemons/environment	WatchPaths	-array-add	/etc/environment.sh	
/Library/LaunchDaemons/environment	WatchPaths	-array-add	/etc/paths	
/Library/LaunchDaemons/environment	WatchPaths	-array-add	/etc/paths.d	'
config_environment () {
  sudo tee "/etc/environment.sh" << 'EOF' > /dev/null
#!/bin/sh

set -e

if test -x /usr/libexec/path_helper; then
  export PATH=""
  eval `/usr/libexec/path_helper -s`
  launchctl setenv PATH $PATH
fi

osascript -e 'tell app "Dock" to quit'
EOF
  sudo chmod a+x "/etc/environment.sh"
  rehash

  la="/Library/LaunchAgents/environment.user"
  ld="/Library/LaunchDaemons/environment"

  sudo mkdir -p "$(dirname $la)" "$(dirname $ld)"
  sudo launchctl unload "${la}.plist" "${ld}.plist" 2> /dev/null
  sudo rm -f "${la}.plist" "${ld}.plist"

  config_defaults "$_environment_defaults" "sudo"
  sudo plutil -convert xml1 "${la}.plist" "${ld}.plist"
  sudo launchctl load "${la}.plist" "${ld}.plist" 2> /dev/null
}

# Configure IPMenulet

config_ipmenulet () {
  _ipm="/Applications/IPMenulet.app/Contents/Resources"
  if test -d "$_ipm"; then
    rm "${_ipm}/icon-19x19-black.png"
    ln "${_ipm}/icon-19x19-white.png" "${_ipm}/icon-19x19-black.png"
  fi
}

# Configure iStat Menus

config_istatmenus () {
  test -d "/Applications/iStat Menus.app" && \
  open "/Applications/iStat Menus.app"
}

# Configure nginx

_nginx_defaults='/Library/LaunchDaemons/org.nginx.nginx	KeepAlive	-bool	true	
/Library/LaunchDaemons/org.nginx.nginx	Label	-string	org.nginx.nginx	
/Library/LaunchDaemons/org.nginx.nginx	ProcessType	-string	Background	
/Library/LaunchDaemons/org.nginx.nginx	Program	-string	/usr/local/bin/nginx	
/Library/LaunchDaemons/org.nginx.nginx	RunAtLoad	-bool	true	
/Library/LaunchDaemons/org.nginx.nginx	StandardErrorPath	-string	/usr/local/var/log/nginx/error.log	
/Library/LaunchDaemons/org.nginx.nginx	StandardOutPath	-string	/usr/local/var/log/nginx/access.log	
/Library/LaunchDaemons/org.nginx.nginx	UserName	-string	root	
/Library/LaunchDaemons/org.nginx.nginx	WatchPaths	-array-add	/usr/local/etc/nginx	'
config_nginx () {
  cat << 'EOF' > /usr/local/etc/nginx/nginx.conf
daemon off;

events {
  accept_mutex off;
  worker_connections 8000;
}

http {
  charset utf-8;
  charset_types
    application/javascript
    application/json
    application/rss+xml
    application/xhtml+xml
    application/xml
    text/css
    text/plain
    text/vnd.wap.wml;

  default_type application/octet-stream;

  error_log /dev/stderr;

  gzip on;
  gzip_comp_level 9;
  gzip_min_length 256;
  gzip_proxied any;
  gzip_static on;
  gzip_vary on;

  gzip_types
    application/atom+xml
    application/javascript
    application/json
    application/ld+json
    application/manifest+json
    application/rss+xml
    application/vnd.geo+json
    application/vnd.ms-fontobject
    application/x-font-ttf
    application/x-web-app-manifest+json
    application/xhtml+xml
    application/xml
    font/opentype
    image/bmp
    image/svg+xml
    image/x-icon
    text/cache-manifest
    text/css
    text/plain
    text/vcard
    text/vnd.rim.location.xloc
    text/vtt
    text/x-component
    text/x-cross-domain-policy;

  index index.html index.xhtml;

  log_format default '$host $status $body_bytes_sent "$request" "$http_referer"\n'
    '  $remote_addr "$http_user_agent"';

  map $http_upgrade $connection_upgrade {
    default upgrade;
    "" close;
  }

  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $connection_upgrade;

  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header X-Real-IP $remote_addr;

  proxy_buffering off;
  proxy_redirect off;

  sendfile on;
  sendfile_max_chunk 512k;

  server_tokens off;

  resolver 8.8.8.8 8.8.4.4 [2001:4860:4860::8888] [2001:4860:4860::8844] valid=300s;
  resolver_timeout 5s;

  # https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
  ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS:!AES128;

  # openssl dhparam -out /etc/letsencrypt/ssl-dhparam.pem 4096
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

  ssl_ecdh_curve secp384r1;
  ssl_prefer_server_ciphers on;
  ssl_protocols TLSv1.2;
  ssl_session_cache shared:TLS:10m;

  types {
    application/atom+xml atom;
    application/font-woff woff;
    application/font-woff2 woff2;
    application/java-archive ear jar war;
    application/javascript js;
    application/json json map topojson;
    application/ld+json jsonld;
    application/mac-binhex40 hqx;
    application/manifest+json webmanifest;
    application/msword doc;
    application/octet-stream bin deb dll dmg exe img iso msi msm msp safariextz;
    application/pdf pdf;
    application/postscript ai eps ps;
    application/rss+xml rss;
    application/rtf rtf;
    application/vnd.geo+json geojson;
    application/vnd.google-earth.kml+xml kml;
    application/vnd.google-earth.kmz kmz;
    application/vnd.ms-excel xls;
    application/vnd.ms-fontobject eot;
    application/vnd.ms-powerpoint ppt;
    application/vnd.openxmlformats-officedocument.presentationml.presentation pptx;
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet xlsx;
    application/vnd.openxmlformats-officedocument.wordprocessingml.document docx;
    application/vnd.wap.wmlc wmlc;
    application/x-7z-compressed 7z;
    application/x-bb-appworld bbaw;
    application/x-bittorrent torrent;
    application/x-chrome-extension crx;
    application/x-cocoa cco;
    application/x-font-ttf ttc ttf;
    application/x-java-archive-diff jardiff;
    application/x-java-jnlp-file jnlp;
    application/x-makeself run;
    application/x-opera-extension oex;
    application/x-perl pl pm;
    application/x-pilot pdb prc;
    application/x-rar-compressed rar;
    application/x-redhat-package-manager rpm;
    application/x-sea sea;
    application/x-shockwave-flash swf;
    application/x-stuffit sit;
    application/x-tcl tcl tk;
    application/x-web-app-manifest+json webapp;
    application/x-x509-ca-cert crt der pem;
    application/x-xpinstall xpi;
    application/xhtml+xml xhtml;
    application/xml rdf xml;
    application/xslt+xml xsl;
    application/zip zip;
    audio/midi mid midi kar;
    audio/mp4 aac f4a f4b m4a;
    audio/mpeg mp3;
    audio/ogg oga ogg opus;
    audio/x-realaudio ra;
    audio/x-wav wav;
    font/opentype otf;
    image/bmp bmp;
    image/gif gif;
    image/jpeg jpeg jpg;
    image/png png;
    image/svg+xml svg svgz;
    image/tiff tif tiff;
    image/vnd.wap.wbmp wbmp;
    image/webp webp;
    image/x-icon cur ico;
    image/x-jng jng;
    text/cache-manifest appcache;
    text/css css;
    text/html htm html shtml;
    text/mathml mml;
    text/plain txt;
    text/vcard vcard vcf;
    text/vnd.rim.location.xloc xloc;
    text/vnd.sun.j2me.app-descriptor jad;
    text/vnd.wap.wml wml;
    text/vtt vtt;
    text/x-component htc;
    video/3gpp 3gp 3gpp;
    video/mp4 f4p f4v m4v mp4;
    video/mpeg mpeg mpg;
    video/ogg ogv;
    video/quicktime mov;
    video/webm webm;
    video/x-flv flv;
    video/x-mng mng;
    video/x-ms-asf asf asx;
    video/x-ms-wmv wmv;
    video/x-msvideo avi;
  }

  include servers/*.conf;
}

worker_processes auto;
EOF

  ld="/Library/LaunchDaemons/org.nginx.nginx"

  sudo mkdir -p "$(dirname $ld)"
  sudo launchctl unload "${ld}.plist" 2> /dev/null
  sudo rm -f "${ld}.plist"

  config_defaults "$_nginx_defaults" "sudo"
  sudo plutil -convert xml1 "${ld}.plist"
  sudo launchctl load "${ld}.plist" 2> /dev/null
}

# Configure OpenSSL
# Create an intentionally invalid certificate for use with a DNS-based ad blocker, e.g. https://pi-hole.net

config_openssl () {
  _default="/etc/letsencrypt/live/default"
  test -d "$_default" || mkdir -p "$_default"

  cat << EOF > "${_default}/default.cnf"
[ req ]
default_bits = 4096
default_keyfile = ${_default}/default.key
default_md = sha256
distinguished_name = dn
encrypt_key = no
prompt = no
utf8 = yes
x509_extensions = v3_ca

[ dn ]
CN = *

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = CA:true
EOF

  openssl req -days 1 -new -newkey rsa -x509 \
    -config "${_default}/default.cnf" \
    -out "${_default}/default.crt"

  cat << EOF > "/usr/local/etc/nginx/servers/default.conf"
server {
  server_name .$(hostname -f | cut -d. -f2-);

  listen 80;
  listen [::]:80;

  return 301 https://\$host\$request_uri;
}

server {
  listen 80 default_server;
  listen [::]:80 default_server;

  listen 443 default_server ssl http2;
  listen [::]:443 default_server ssl http2;

  ssl_certificate ${_default}/default.crt;
  ssl_certificate_key ${_default}/default.key;

  ssl_ciphers NULL;

  return 204;
}
EOF
}

# Configure System Preferences

config_sysprefs () {
  config_energy
  config_loginwindow
  config_mas
}

# Configure Energy Saver

_energy='-c	displaysleep	20
-c	sleep	0
-c	disksleep	60
-c	womp	1
-c	autorestart	1
-c	powernap	1
-u	displaysleep	2
-u	lessbright	1
-u	haltafter	5
-u	haltremain	-1
-u	haltlevel	-1'

config_energy () {
  printf "%s\n" "${_energy}" | \
  while IFS="$(printf '\t')" read flag setting value; do
    sudo pmset $flag ${setting} ${value}
  done
}

# Configure Login Window

_loginwindow='/Library/Preferences/com.apple.loginwindow
SHOWFULLNAME
-bool
true
'

config_loginwindow () {
  config_defaults "${_loginwindow}" "sudo"
}

# Configure App Store

_swupdate='/Library/Preferences/com.apple.commerce	AutoUpdate	-bool	true	
/Library/Preferences/com.apple.commerce	AutoUpdateRestartRequired	-bool	true	'

config_mas () {
  config_defaults "${_swupdate}" "sudo"
}

# Configure Z-Shell

config_zsh () {
  grep -q "$(which zsh)" /etc/shells ||
  print "$(which zsh)\n" | \
  sudo tee -a /etc/shells > /dev/null

  case "$SHELL" in
    ($(which zsh)) ;;
    (*)
      chsh -s "$(which zsh)"
      sudo chsh -s $(which zsh) ;;
  esac

  sudo tee -a /etc/zshenv << 'EOF' > /dev/null
#-- Exports ----------------------------------------------------

export \
  ZDOTDIR="${HOME}/.zsh" \
  MASDIR="$(getconf DARWIN_USER_CACHE_DIR)com.apple.appstore" \
  NODENV_ROOT="/usr/local/node" \
  PLENV_ROOT="/usr/local/perl" \
  PYENV_ROOT="/usr/local/python" \
  RBENV_ROOT="/usr/local/ruby" \
  EDITOR="vi" \
  VISUAL="vi" \
  PAGER="less" \
  LANG="en_US.UTF-8" \
  LESS="-egiMQRS -x2 -z-2" \
  LESSHISTFILE="/dev/null" \
  HISTSIZE=50000 \
  SAVEHIST=50000 \
  KEYTIMEOUT=1

test -d "$ZDOTDIR" || \
  mkdir -p "$ZDOTDIR"

test -f "${ZDOTDIR}/.zshrc" || \
  touch "${ZDOTDIR}/.zshrc"

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path
EOF
  sudo chmod +x "/etc/zshenv"
  . "/etc/zshenv"

  sudo tee /etc/zshrc << 'EOF' > /dev/null
#-- Exports ----------------------------------------------------

export \
  HISTFILE="${ZDOTDIR:-$HOME}/.zhistory"

#-- Changing Directories ---------------------------------------

setopt \
  autocd \
  autopushd \
  cdablevars \
  chasedots \
  chaselinks \
  NO_posixcd \
  pushdignoredups \
  no_pushdminus \
  pushdsilent \
  pushdtohome

#-- Completion -------------------------------------------------

setopt \
  ALWAYSLASTPROMPT \
  no_alwaystoend \
  AUTOLIST \
  AUTOMENU \
  autonamedirs \
  AUTOPARAMKEYS \
  AUTOPARAMSLASH \
  AUTOREMOVESLASH \
  no_bashautolist \
  no_completealiases \
  completeinword \
  no_globcomplete \
  HASHLISTALL \
  LISTAMBIGUOUS \
  no_LISTBEEP \
  no_listpacked \
  no_listrowsfirst \
  LISTTYPES \
  no_menucomplete \
  no_recexact

#-- Expansion and Globbing -------------------------------------

setopt \
  BADPATTERN \
  BAREGLOBQUAL \
  braceccl \
  CASEGLOB \
  CASEMATCH \
  NO_cshnullglob \
  EQUALS \
  extendedglob \
  no_forcefloat \
  GLOB \
  NO_globassign \
  no_globdots \
  no_globstarshort \
  NO_globsubst \
  no_histsubstpattern \
  NO_ignorebraces \
  no_ignoreclosebraces \
  NO_kshglob \
  no_magicequalsubst \
  no_markdirs \
  MULTIBYTE \
  NOMATCH \
  no_nullglob \
  no_numericglobsort \
  no_rcexpandparam \
  no_rematchpcre \
  NO_shglob \
  UNSET \
  no_warncreateglobal \
  no_warnnestedvar

#-- History ----------------------------------------------------

setopt \
  APPENDHISTORY \
  BANGHIST \
  extendedhistory \
  no_histallowclobber \
  no_HISTBEEP \
  histexpiredupsfirst \
  no_histfcntllock \
  histfindnodups \
  histignorealldups \
  histignoredups \
  histignorespace \
  histlexwords \
  no_histnofunctions \
  no_histnostore \
  histreduceblanks \
  HISTSAVEBYCOPY \
  histsavenodups \
  histverify \
  incappendhistory \
  incappendhistorytime \
  sharehistory

#-- Initialisation ---------------------------------------------

setopt \
  no_allexport \
  GLOBALEXPORT \
  GLOBALRCS \
  RCS

#-- Input/Output -----------------------------------------------

setopt \
  ALIASES \
  no_CLOBBER \
  no_correct \
  no_correctall \
  dvorak \
  no_FLOWCONTROL \
  no_ignoreeof \
  NO_interactivecomments \
  HASHCMDS \
  HASHDIRS \
  no_hashexecutablesonly \
  no_mailwarning \
  pathdirs \
  NO_pathscript \
  no_printeightbit \
  no_printexitvalue \
  rcquotes \
  NO_rmstarsilent \
  no_rmstarwait \
  SHORTLOOPS \
  no_sunkeyboardhack

#-- Job Control ------------------------------------------------

setopt \
  no_autocontinue \
  autoresume \
  no_BGNICE \
  CHECKJOBS \
  no_HUP \
  longlistjobs \
  MONITOR \
  NOTIFY \
  NO_posixjobs

#-- Prompting --------------------------------------------------

setopt \
  NO_promptbang \
  PROMPTCR \
  PROMPTSP \
  PROMPTPERCENT \
  promptsubst \
  transientrprompt

#-- Scripts and Functions --------------------------------------

setopt \
  NO_aliasfuncdef \
  no_cbases \
  no_cprecedences \
  DEBUGBEFORECMD \
  no_errexit \
  no_errreturn \
  EVALLINENO \
  EXEC \
  FUNCTIONARGZERO \
  no_localloops \
  NO_localoptions \
  no_localpatterns \
  NO_localtraps \
  MULTIFUNCDEF \
  MULTIOS \
  NO_octalzeroes \
  no_pipefail \
  no_sourcetrace \
  no_typesetsilent \
  no_verbose \
  no_xtrace

#-- Shell Emulation --------------------------------------------

setopt \
  NO_appendcreate \
  no_bashrematch \
  NO_bsdecho \
  no_continueonerror \
  NO_cshjunkiehistory \
  NO_cshjunkieloops \
  NO_cshjunkiequotes \
  NO_cshnullcmd \
  NO_ksharrays \
  NO_kshautoload \
  NO_kshoptionprint \
  no_kshtypeset \
  no_kshzerosubscript \
  NO_posixaliases \
  no_posixargzero \
  NO_posixbuiltins \
  NO_posixidentifiers \
  NO_posixstrings \
  NO_posixtraps \
  NO_shfileexpansion \
  NO_shnullcmd \
  NO_shoptionletters \
  NO_shwordsplit \
  no_trapsasync

#-- Zle --------------------------------------------------------

setopt \
  no_BEEP \
  combiningchars \
  no_overstrike \
  NO_singlelinezle

#-- Aliases ----------------------------------------------------

alias \
  ll="/bin/ls -aFGHhlOw"

#-- Functions --------------------------------------------------

autoload -Uz \
  add-zsh-hook \
  compaudit \
  compinit

compaudit 2> /dev/null | \
  xargs -L 1 chmod go-w 2> /dev/null

compinit -u

which nodenv > /dev/null && \
  eval "$(nodenv init - zsh)"

which plenv > /dev/null && \
  eval "$(plenv init - zsh)"

which pyenv > /dev/null && \
  eval "$(pyenv init - zsh)"

which rbenv > /dev/null && \
  eval "$(rbenv init - zsh)"

sf () {
  SetFile -P -d "$1 12:00:00" -m "$1 12:00:00" $argv[2,$]
}

ssh-add -A 2> /dev/null

#-- zsh-syntax-highlighting ------------------------------------

. "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

#-- zsh-history-substring-search -------------------------------

. "$(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh"

HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="fg=default,underline" && \
  export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND="fg=red,underline" && \
  export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND

#-- Zle --------------------------------------------------------

zmodload zsh/zle

bindkey -d
bindkey -v

for k in "vicmd" "viins"; do
  bindkey -M $k '\C-A' beginning-of-line
  bindkey -M $k '\C-E' end-of-line
  bindkey -M $k '\C-U' kill-whole-line
  bindkey -M $k '\e[3~' delete-char
  bindkey -M $k '\e[A' history-substring-search-up
  bindkey -M $k '\e[B' history-substring-search-down
  bindkey -M $k '\x7f' backward-delete-char
done

for f in \
  "zle-keymap-select" \
  "zle-line-finish" \
  "zle-line-init"
do
  eval "$f () {
    case \$TERM_PROGRAM in
      ('Apple_Terminal')
        test \$KEYMAP = 'vicmd' && \
          printf '%b' '\e[4 q' || \
          printf '%b' '\e[6 q' ;;
      ('iTerm.app')
        test \$KEYMAP = 'vicmd' && \
          printf '%b' '\e]Plf27f7f\e\x5c\e[4 q' || \
          printf '%b' '\e]Pl99cc99\e\x5c\e[6 q' ;;
    esac
  }"
  zle -N $f
done

#-- prompt_ptb_setup -------------------------------------------

prompt_ptb_setup () {
  I="$(printf '%b' '%{\e[3m%}')"
  i="$(printf '%b' '%{\e[0m%}')"
  PROMPT="%F{004}$I%d$i %(!.%F{001}.%F{002})%n %B❯%b%f " && \
  export PROMPT
}

prompt_ptb_setup

prompt_ptb_precmd () {
  if test "$(uname -s)" = "Darwin"; then
    print -Pn "\e]7;file://%M\${PWD// /%%20}\a"
    print -Pn "\e]2;%n@%m\a"
    print -Pn "\e]1;%~\a"
  fi

  test -n "$(git rev-parse --git-dir 2> /dev/null)" && \
  RPROMPT="%F{000}$(git rev-parse --abbrev-ref HEAD 2> /dev/null)%f" && \
  export RPROMPT
}

add-zsh-hook precmd \
  prompt_ptb_precmd
EOF
  sudo chmod +x "/etc/zshrc"
  . "/etc/zshrc"
}

# Configure New Account

config_new_account () {
  e="$(ask 'New macOS Account: Email Address?' 'OK' '')"
  curl --output "/Library/User Pictures/${e}.jpg" --silent \
    "https://www.gravatar.com/avatar/$(md5 -qs ${e}).jpg?s=512"

  g="$(curl --location --silent \
    "https://api.github.com/search/users?q=${e}" | \
    sed -n 's/^.*"url": "\(.*\)".*/\1/p')"
  g="$(curl --location --silent ${g})"

  n="$(printf ${g} | sed -n 's/^.*"name": "\(.*\)".*/\1/p')"
  n="$(ask 'New macOS Account: Real Name?' 'OK' ${n})"

  u="$(printf ${g} | sed -n 's/^.*"login": "\(.*\)".*/\1/p')"
  u="$(ask 'New macOS Account: User Name?' 'OK' ${u})"

  sudo defaults write \
    "/System/Library/User Template/Non_localized/Library/Preferences/.GlobalPreferences.plist" \
    "com.apple.swipescrolldirection" -bool false

  sudo sysadminctl -admin -addUser "${u}" -fullName "${n}" -password - \
    -shell "$(which zsh)" -picture "/Library/User Pictures/${e}.jpg"
}

# Configure Guest Users

config_guest () {
  sudo sysadminctl -guestAccount off
}

# Reinstate =sudo= Password

config_rm_sudoers () {
  sudo -- sh -c \
    "rm -f /etc/sudoers.d/wheel; dscl /Local/Default -delete /Groups/wheel GroupMembership $(whoami)"

  /usr/bin/read -n 1 -p "Press any key to continue.
" -s
  if run "Log Out Then Log Back In?" "Cancel" "Log Out"; then
    osascript -e 'tell app "loginwindow" to «event aevtrlgo»'
  fi
}

# Define Function =custom=

custom () {
  custom_githome
  custom_atom
  custom_autoping
  custom_dropbox
  custom_duti
  custom_emacs
  custom_finder
  custom_getmail
  custom_git
  custom_gnupg
  custom_istatmenus
  custom_meteorologist
  custom_moom
  custom_mp4_automator
  custom_nvalt
  custom_nzbget
  custom_safari
  custom_sieve
  custom_sonarr
  custom_ssh
  custom_sysprefs
  custom_terminal
  custom_vim
  custom_vlc

  which personalize_all
}

# Customize Home

custom_githome () {
  git -C "${HOME}" init

  test -f "${CACHES}/dbx/.zshenv" && \
    mkdir -p "${ZDOTDIR:-$HOME}" && \
    cp "${CACHES}/dbx/.zshenv" "${ZDOTDIR:-$HOME}" && \
    . "${ZDOTDIR:-$HOME}/.zshenv"

  a=$(ask "Existing Git Home Repository Path or URL" "Add Remote" "")
  if test -n "${a}"; then
    git -C "${HOME}" remote add origin "${a}"
    git -C "${HOME}" fetch origin master
  fi

  if run "Encrypt and commit changes to Git and push to GitHub, automatically?" "No" "Add AutoKeep"; then
    curl --location --silent \
      "https://github.com/ptb/autokeep/raw/master/autokeep.command" | \
      . /dev/stdin 0

    autokeep_remote
    autokeep_push
    autokeep_gitignore
    autokeep_post_commit
    autokeep_launchagent
    autokeep_crypt

    git reset --hard
    git checkout -f -b master FETCH_HEAD
  fi

  chmod -R go= "${HOME}" > /dev/null 2>&1
}

# Customize Atom

_atom='atom-beautify
atom-css-comb
atom-fuzzy-grep
atom-jade
atom-wallaby
autoclose-html
autocomplete-python
busy-signal
double-tag
editorconfig
ex-mode
file-icons
git-plus
git-time-machine
highlight-selected
intentions
language-docker
language-jade
language-javascript-jsx
language-lisp
language-slim
linter
linter-eslint
linter-rubocop
linter-shellcheck
linter-ui-default
MagicPython
python-yapf
react
riot
sort-lines
term3
tomorrow-night-eighties-syntax
tree-view-open-files
vim-mode-plus
vim-mode-zz'

custom_atom () {
  if which apm > /dev/null; then
    mkdir -p "${HOME}/.atom/.apm"

    cat << EOF > "${HOME}/.atom/.apmrc"
cache = ${CACHES}/apm
EOF

    cat << EOF > "${HOME}/.atom/.apm/.apmrc"
cache = ${CACHES}/apm
EOF

    printf "%s\n" "${_atom}" | \
    while IFS="$(printf '\t')" read pkg; do
      test -d "${HOME}/.atom/packages/${pkg}" ||
      apm install "${pkg}"
    done

    cat << EOF > "${HOME}/.atom/config.cson"
"*":
  "autocomplete-python":
    useKite: false
  core:
    telemetryConsent: "limited"
    themes: [
      "one-dark-ui"
      "tomorrow-night-eighties-syntax"
    ]
  editor:
    fontFamily: "Inconsolata LGC"
    fontSize: 13
  welcome:
    showOnStartup: false
EOF

    cat << EOF > "${HOME}/.atom/packages/tomorrow-night-eighties-syntax/styles/colors.less"
@background: #222222;
@current-line: #333333;
@selection: #4c4c4c;
@foreground: #cccccc;
@comment: #999999;
@red: #f27f7f;
@orange: #ff994c;
@yellow: #ffcc66;
@green: #99cc99;
@aqua: #66cccc;
@blue: #6699cc;
@purple: #cc99cc;
EOF
  fi
}

# Customize autoping

_autoping='com.memset.autoping	Hostname	-string	google.com	
com.memset.autoping	SlowPingLowThreshold	-int	100	
com.memset.autoping	LaunchAtLogin	-bool	true	
com.memset.autoping	ShowIcon	-bool	true	
com.memset.autoping	ShowText	-bool	true	
com.memset.autoping	ShowPacketLossText	-bool	true	
com.memset.autoping	ShowNotifications	-bool	true	'

custom_autoping () {
  config_defaults "${_autoping}"
}

# Customize Dropbox

custom_dropbox () {
  test -d "/Applications/Dropbox.app" && \
    open "/Applications/Dropbox.app"
}

# Customize Default UTIs

_duti='com.apple.DiskImageMounter	com.apple.disk-image	all
com.apple.DiskImageMounter	public.disk-image	all
com.apple.DiskImageMounter	public.iso-image	all
com.apple.QuickTimePlayerX	com.apple.coreaudio-format	all
com.apple.QuickTimePlayerX	com.apple.quicktime-movie	all
com.apple.QuickTimePlayerX	com.microsoft.waveform-audio	all
com.apple.QuickTimePlayerX	public.aifc-audio	all
com.apple.QuickTimePlayerX	public.aiff-audio	all
com.apple.QuickTimePlayerX	public.audio	all
com.apple.QuickTimePlayerX	public.mp3	all
com.apple.Safari	com.compuserve.gif	all
com.apple.Terminal	com.apple.terminal.shell-script	all
com.apple.iTunes	com.apple.iTunes.audible	all
com.apple.iTunes	com.apple.iTunes.ipg	all
com.apple.iTunes	com.apple.iTunes.ipsw	all
com.apple.iTunes	com.apple.iTunes.ite	all
com.apple.iTunes	com.apple.iTunes.itlp	all
com.apple.iTunes	com.apple.iTunes.itms	all
com.apple.iTunes	com.apple.iTunes.podcast	all
com.apple.iTunes	com.apple.m4a-audio	all
com.apple.iTunes	com.apple.mpeg-4-ringtone	all
com.apple.iTunes	com.apple.protected-mpeg-4-audio	all
com.apple.iTunes	com.apple.protected-mpeg-4-video	all
com.apple.iTunes	com.audible.aa-audio	all
com.apple.iTunes	public.mpeg-4-audio	all
com.apple.installer	com.apple.installer-package-archive	all
com.github.atom	com.apple.binary-property-list	editor
com.github.atom	com.apple.crashreport	editor
com.github.atom	com.apple.dt.document.ascii-property-list	editor
com.github.atom	com.apple.dt.document.script-suite-property-list	editor
com.github.atom	com.apple.dt.document.script-terminology-property-list	editor
com.github.atom	com.apple.log	editor
com.github.atom	com.apple.property-list	editor
com.github.atom	com.apple.rez-source	editor
com.github.atom	com.apple.symbol-export	editor
com.github.atom	com.apple.xcode.ada-source	editor
com.github.atom	com.apple.xcode.bash-script	editor
com.github.atom	com.apple.xcode.configsettings	editor
com.github.atom	com.apple.xcode.csh-script	editor
com.github.atom	com.apple.xcode.fortran-source	editor
com.github.atom	com.apple.xcode.ksh-script	editor
com.github.atom	com.apple.xcode.lex-source	editor
com.github.atom	com.apple.xcode.make-script	editor
com.github.atom	com.apple.xcode.mig-source	editor
com.github.atom	com.apple.xcode.pascal-source	editor
com.github.atom	com.apple.xcode.strings-text	editor
com.github.atom	com.apple.xcode.tcsh-script	editor
com.github.atom	com.apple.xcode.yacc-source	editor
com.github.atom	com.apple.xcode.zsh-script	editor
com.github.atom	com.apple.xml-property-list	editor
com.github.atom	com.barebones.bbedit.actionscript-source	editor
com.github.atom	com.barebones.bbedit.erb-source	editor
com.github.atom	com.barebones.bbedit.ini-configuration	editor
com.github.atom	com.barebones.bbedit.javascript-source	editor
com.github.atom	com.barebones.bbedit.json-source	editor
com.github.atom	com.barebones.bbedit.jsp-source	editor
com.github.atom	com.barebones.bbedit.lasso-source	editor
com.github.atom	com.barebones.bbedit.lua-source	editor
com.github.atom	com.barebones.bbedit.setext-source	editor
com.github.atom	com.barebones.bbedit.sql-source	editor
com.github.atom	com.barebones.bbedit.tcl-source	editor
com.github.atom	com.barebones.bbedit.tex-source	editor
com.github.atom	com.barebones.bbedit.textile-source	editor
com.github.atom	com.barebones.bbedit.vbscript-source	editor
com.github.atom	com.barebones.bbedit.vectorscript-source	editor
com.github.atom	com.barebones.bbedit.verilog-hdl-source	editor
com.github.atom	com.barebones.bbedit.vhdl-source	editor
com.github.atom	com.barebones.bbedit.yaml-source	editor
com.github.atom	com.netscape.javascript-source	editor
com.github.atom	com.sun.java-source	editor
com.github.atom	dyn.ah62d4rv4ge80255drq	all
com.github.atom	dyn.ah62d4rv4ge80g55gq3w0n	all
com.github.atom	dyn.ah62d4rv4ge80g55sq2	all
com.github.atom	dyn.ah62d4rv4ge80y2xzrf0gk3pw	all
com.github.atom	dyn.ah62d4rv4ge81e3dtqq	all
com.github.atom	dyn.ah62d4rv4ge81e7k	all
com.github.atom	dyn.ah62d4rv4ge81g25xsq	all
com.github.atom	dyn.ah62d4rv4ge81g2pxsq	all
com.github.atom	net.daringfireball.markdown	editor
com.github.atom	public.assembly-source	editor
com.github.atom	public.c-header	editor
com.github.atom	public.c-plus-plus-source	editor
com.github.atom	public.c-source	editor
com.github.atom	public.csh-script	editor
com.github.atom	public.json	editor
com.github.atom	public.lex-source	editor
com.github.atom	public.log	editor
com.github.atom	public.mig-source	editor
com.github.atom	public.nasm-assembly-source	editor
com.github.atom	public.objective-c-plus-plus-source	editor
com.github.atom	public.objective-c-source	editor
com.github.atom	public.patch-file	editor
com.github.atom	public.perl-script	editor
com.github.atom	public.php-script	editor
com.github.atom	public.plain-text	editor
com.github.atom	public.precompiled-c-header	editor
com.github.atom	public.precompiled-c-plus-plus-header	editor
com.github.atom	public.python-script	editor
com.github.atom	public.ruby-script	editor
com.github.atom	public.script	editor
com.github.atom	public.shell-script	editor
com.github.atom	public.source-code	editor
com.github.atom	public.text	editor
com.github.atom	public.utf16-external-plain-text	editor
com.github.atom	public.utf16-plain-text	editor
com.github.atom	public.utf8-plain-text	editor
com.github.atom	public.xml	editor
com.kodlian.Icon-Slate	com.apple.icns	all
com.kodlian.Icon-Slate	com.microsoft.ico	all
com.microsoft.Word	public.rtf	all
com.panayotis.jubler	dyn.ah62d4rv4ge81g6xy	all
com.sketchup.SketchUp.2017	com.sketchup.skp	all
com.VortexApps.NZBVortex3	dyn.ah62d4rv4ge8068xc	all
com.vmware.fusion	com.microsoft.windows-executable	all
cx.c3.theunarchiver	com.alcohol-soft.mdf-image	all
cx.c3.theunarchiver	com.allume.stuffit-archive	all
cx.c3.theunarchiver	com.altools.alz-archive	all
cx.c3.theunarchiver	com.amiga.adf-archive	all
cx.c3.theunarchiver	com.amiga.adz-archive	all
cx.c3.theunarchiver	com.apple.applesingle-archive	all
cx.c3.theunarchiver	com.apple.binhex-archive	all
cx.c3.theunarchiver	com.apple.bom-compressed-cpio	all
cx.c3.theunarchiver	com.apple.itunes.ipa	all
cx.c3.theunarchiver	com.apple.macbinary-archive	all
cx.c3.theunarchiver	com.apple.self-extracting-archive	all
cx.c3.theunarchiver	com.apple.xar-archive	all
cx.c3.theunarchiver	com.apple.xip-archive	all
cx.c3.theunarchiver	com.cyclos.cpt-archive	all
cx.c3.theunarchiver	com.microsoft.cab-archive	all
cx.c3.theunarchiver	com.microsoft.msi-installer	all
cx.c3.theunarchiver	com.nero.nrg-image	all
cx.c3.theunarchiver	com.network172.pit-archive	all
cx.c3.theunarchiver	com.nowsoftware.now-archive	all
cx.c3.theunarchiver	com.nscripter.nsa-archive	all
cx.c3.theunarchiver	com.padus.cdi-image	all
cx.c3.theunarchiver	com.pkware.zip-archive	all
cx.c3.theunarchiver	com.rarlab.rar-archive	all
cx.c3.theunarchiver	com.redhat.rpm-archive	all
cx.c3.theunarchiver	com.stuffit.archive.sit	all
cx.c3.theunarchiver	com.stuffit.archive.sitx	all
cx.c3.theunarchiver	com.sun.java-archive	all
cx.c3.theunarchiver	com.symantec.dd-archive	all
cx.c3.theunarchiver	com.winace.ace-archive	all
cx.c3.theunarchiver	com.winzip.zipx-archive	all
cx.c3.theunarchiver	cx.c3.arc-archive	all
cx.c3.theunarchiver	cx.c3.arj-archive	all
cx.c3.theunarchiver	cx.c3.dcs-archive	all
cx.c3.theunarchiver	cx.c3.dms-archive	all
cx.c3.theunarchiver	cx.c3.ha-archive	all
cx.c3.theunarchiver	cx.c3.lbr-archive	all
cx.c3.theunarchiver	cx.c3.lha-archive	all
cx.c3.theunarchiver	cx.c3.lhf-archive	all
cx.c3.theunarchiver	cx.c3.lzx-archive	all
cx.c3.theunarchiver	cx.c3.packdev-archive	all
cx.c3.theunarchiver	cx.c3.pax-archive	all
cx.c3.theunarchiver	cx.c3.pma-archive	all
cx.c3.theunarchiver	cx.c3.pp-archive	all
cx.c3.theunarchiver	cx.c3.xmash-archive	all
cx.c3.theunarchiver	cx.c3.zoo-archive	all
cx.c3.theunarchiver	cx.c3.zoom-archive	all
cx.c3.theunarchiver	org.7-zip.7-zip-archive	all
cx.c3.theunarchiver	org.archive.warc-archive	all
cx.c3.theunarchiver	org.debian.deb-archive	all
cx.c3.theunarchiver	org.gnu.gnu-tar-archive	all
cx.c3.theunarchiver	org.gnu.gnu-zip-archive	all
cx.c3.theunarchiver	org.gnu.gnu-zip-tar-archive	all
cx.c3.theunarchiver	org.tukaani.lzma-archive	all
cx.c3.theunarchiver	org.tukaani.xz-archive	all
cx.c3.theunarchiver	public.bzip2-archive	all
cx.c3.theunarchiver	public.cpio-archive	all
cx.c3.theunarchiver	public.tar-archive	all
cx.c3.theunarchiver	public.tar-bzip2-archive	all
cx.c3.theunarchiver	public.z-archive	all
cx.c3.theunarchiver	public.zip-archive	all
cx.c3.theunarchiver	public.zip-archive.first-part	all
org.gnu.Emacs	dyn.ah62d4rv4ge8086xh	all
org.inkscape.Inkscape	public.svg-image	editor
org.videolan.vlc	com.apple.m4v-video	all
org.videolan.vlc	com.microsoft.windows-media-wmv	all
org.videolan.vlc	org.videolan.3gp	all
org.videolan.vlc	org.videolan.aac	all
org.videolan.vlc	org.videolan.ac3	all
org.videolan.vlc	org.videolan.aiff	all
org.videolan.vlc	org.videolan.amr	all
org.videolan.vlc	org.videolan.aob	all
org.videolan.vlc	org.videolan.ape	all
org.videolan.vlc	org.videolan.asf	all
org.videolan.vlc	org.videolan.avi	all
org.videolan.vlc	org.videolan.axa	all
org.videolan.vlc	org.videolan.axv	all
org.videolan.vlc	org.videolan.divx	all
org.videolan.vlc	org.videolan.dts	all
org.videolan.vlc	org.videolan.dv	all
org.videolan.vlc	org.videolan.flac	all
org.videolan.vlc	org.videolan.flash	all
org.videolan.vlc	org.videolan.gxf	all
org.videolan.vlc	org.videolan.it	all
org.videolan.vlc	org.videolan.mid	all
org.videolan.vlc	org.videolan.mka	all
org.videolan.vlc	org.videolan.mkv	all
org.videolan.vlc	org.videolan.mlp	all
org.videolan.vlc	org.videolan.mod	all
org.videolan.vlc	org.videolan.mpc	all
org.videolan.vlc	org.videolan.mpeg-audio	all
org.videolan.vlc	org.videolan.mpeg-stream	all
org.videolan.vlc	org.videolan.mpeg-video	all
org.videolan.vlc	org.videolan.mxf	all
org.videolan.vlc	org.videolan.nsv	all
org.videolan.vlc	org.videolan.nuv	all
org.videolan.vlc	org.videolan.ogg-audio	all
org.videolan.vlc	org.videolan.ogg-video	all
org.videolan.vlc	org.videolan.oma	all
org.videolan.vlc	org.videolan.opus	all
org.videolan.vlc	org.videolan.quicktime	all
org.videolan.vlc	org.videolan.realmedia	all
org.videolan.vlc	org.videolan.rec	all
org.videolan.vlc	org.videolan.rmi	all
org.videolan.vlc	org.videolan.s3m	all
org.videolan.vlc	org.videolan.spx	all
org.videolan.vlc	org.videolan.tod	all
org.videolan.vlc	org.videolan.tta	all
org.videolan.vlc	org.videolan.vob	all
org.videolan.vlc	org.videolan.voc	all
org.videolan.vlc	org.videolan.vqf	all
org.videolan.vlc	org.videolan.vro	all
org.videolan.vlc	org.videolan.wav	all
org.videolan.vlc	org.videolan.webm	all
org.videolan.vlc	org.videolan.wma	all
org.videolan.vlc	org.videolan.wmv	all
org.videolan.vlc	org.videolan.wtv	all
org.videolan.vlc	org.videolan.wv	all
org.videolan.vlc	org.videolan.xa	all
org.videolan.vlc	org.videolan.xesc	all
org.videolan.vlc	org.videolan.xm	all
org.videolan.vlc	public.ac3-audio	all
org.videolan.vlc	public.audiovisual-content	all
org.videolan.vlc	public.avi	all
org.videolan.vlc	public.movie	all
org.videolan.vlc	public.mpeg	all
org.videolan.vlc	public.mpeg-2-video	all
org.videolan.vlc	public.mpeg-4	all'
custom_duti () {
  if test -x "/usr/local/bin/duti"; then
    test -f "${HOME}/Library/Preferences/org.duti.plist" && \
      rm "${HOME}/Library/Preferences/org.duti.plist"

    printf "%s\n" "${_duti}" | \
    while IFS="$(printf '\t')" read id uti role; do
      defaults write org.duti DUTISettings -array-add \
        "{
          DUTIBundleIdentifier = '$a';
          DUTIUniformTypeIdentifier = '$b';
          DUTIRole = '$c';
        }"
    done

    duti "${HOME}/Library/Preferences/org.duti.plist" 2> /dev/null
  fi
}

# Customize Emacs

custom_emacs () {
  mkdir -p "${HOME}/.emacs.d" && \
  curl --compressed --location --silent \
    "https://github.com/syl20bnr/spacemacs/archive/master.tar.gz" | \
  tar -C "${HOME}/.emacs.d" --strip-components 1 -xf -
  mkdir -p "${HOME}/.emacs.d/private/ptb"
  chmod -R go= "${HOME}/.emacs.d"

  cat << EOF > "${HOME}/.spacemacs"
(defun dotspacemacs/layers ()
  (setq-default
    dotspacemacs-configuration-layers '(
      auto-completion
      (colors :variables
        colors-colorize-identifiers 'variables)
      dash
      deft
      docker
      emacs-lisp
      evil-cleverparens
      git
      github
      helm
      html
      ibuffer
      imenu-list
      javascript
      markdown
      nginx
      (org :variables
        org-enable-github-support t)
      (osx :variables
        osx-use-option-as-meta nil)
      ptb
      react
      ruby
      ruby-on-rails
      search-engine
      semantic
      shell-scripts
      (spell-checking :variables
        spell-checking-enable-by-default nil)
      syntax-checking
      (version-control :variables
        version-control-diff-side 'left)
      vim-empty-lines
    )
    dotspacemacs-excluded-packages '(org-bullets)
  )
)

(defun dotspacemacs/init ()
  (setq-default
    dotspacemacs-startup-banner nil
    dotspacemacs-startup-lists nil
    dotspacemacs-scratch-mode 'org-mode
    dotspacemacs-themes '(sanityinc-tomorrow-eighties)
    dotspacemacs-default-font '(
      "Inconsolata LGC"
      :size 13
      :weight normal
      :width normal
      :powerline-scale 1.1)
    dotspacemacs-loading-progress-bar nil
    dotspacemacs-active-transparency 100
    dotspacemacs-inactive-transparency 100
    dotspacemacs-line-numbers t
    dotspacemacs-whitespace-cleanup 'all
  )
)

(defun dotspacemacs/user-init ())
(defun dotspacemacs/user-config ())
EOF

  cat << EOF > "${HOME}/.emacs.d/private/ptb/config.el"
(setq
  default-frame-alist '(
    (top . 22)
    (left . 1201)
    (height . 50)
    (width . 120)
    (vertical-scroll-bars . right))
  initial-frame-alist (copy-alist default-frame-alist)

  deft-directory "~/Dropbox/Notes"
  focus-follows-mouse t
  mouse-wheel-follow-mouse t
  mouse-wheel-scroll-amount '(1 ((shift) . 1))
  org-src-preserve-indentation t
  purpose-display-at-right 20
  recentf-max-saved-items 5
  scroll-step 1
  system-uses-terminfo nil

  ibuffer-formats '(
    (mark modified read-only " "
    (name 18 18 :left :elide)))

  ibuffer-shrink-to-minimum-size t
  ibuffer-always-show-last-buffer nil
  ibuffer-sorting-mode 'recency
  ibuffer-use-header-line nil
  x-select-enable-clipboard nil)

(global-linum-mode t)
(recentf-mode t)
(x-focus-frame nil)
(with-eval-after-load 'org
  (org-babel-do-load-languages
    'org-babel-load-languages '(
      (ruby . t)
      (shell . t)
    )
  )
)
EOF

  cat << EOF > "${HOME}/.emacs.d/private/ptb/funcs.el"
(defun is-useless-buffer (buffer)
  (let ((name (buffer-name buffer)))
    (and (= ?* (aref name 0))
        (string-match "^\\**" name))))

(defun kill-useless-buffers ()
  (interactive)
  (loop for buffer being the buffers
        do (and (is-useless-buffer buffer) (kill-buffer buffer))))

(defun org-babel-tangle-hook ()
  (add-hook 'after-save-hook 'org-babel-tangle))

(add-hook 'org-mode-hook #'org-babel-tangle-hook)

(defun ptb/new-untitled-buffer ()
  "Create a new untitled buffer in the current frame."
  (interactive)
  (let
    ((buffer "Untitled-") (count 1))
    (while
      (get-buffer (concat buffer (number-to-string count)))
      (setq count (1+ count)))
    (switch-to-buffer
    (concat buffer (number-to-string count))))
  (org-mode))

(defun ptb/previous-buffer ()
  (interactive)
  (kill-useless-buffers)
  (previous-buffer))

(defun ptb/next-buffer ()
  (interactive)
  (kill-useless-buffers)
  (next-buffer))

(defun ptb/kill-current-buffer ()
  (interactive)
  (kill-buffer (current-buffer))
  (kill-useless-buffers))
EOF

  cat << EOF > "${HOME}/.emacs.d/private/ptb/keybindings.el"
(define-key evil-insert-state-map (kbd "<return>") 'newline)

(define-key evil-normal-state-map (kbd "s-c") 'clipboard-kill-ring-save)
(define-key evil-insert-state-map (kbd "s-c") 'clipboard-kill-ring-save)
(define-key evil-visual-state-map (kbd "s-c") 'clipboard-kill-ring-save)

(define-key evil-ex-completion-map (kbd "s-v") 'clipboard-yank)
(define-key evil-ex-search-keymap (kbd "s-v") 'clipboard-yank)
(define-key evil-insert-state-map (kbd "s-v") 'clipboard-yank)

(define-key evil-normal-state-map (kbd "s-x") 'clipboard-kill-region)
(define-key evil-insert-state-map (kbd "s-x") 'clipboard-kill-region)
(define-key evil-visual-state-map (kbd "s-x") 'clipboard-kill-region)

(define-key evil-normal-state-map (kbd "<S-up>") 'evil-previous-visual-line)
(define-key evil-insert-state-map (kbd "<S-up>") 'evil-previous-visual-line)
(define-key evil-visual-state-map (kbd "<S-up>") 'evil-previous-visual-line)

(define-key evil-normal-state-map (kbd "<S-down>") 'evil-next-visual-line)
(define-key evil-insert-state-map (kbd "<S-down>") 'evil-next-visual-line)
(define-key evil-visual-state-map (kbd "<S-down>") 'evil-next-visual-line)

(global-set-key (kbd "C-l") 'evil-search-highlight-persist-remove-all)

(global-set-key (kbd "s-t") 'make-frame)
(global-set-key (kbd "s-n") 'ptb/new-untitled-buffer)
(global-set-key (kbd "s-w") 'ptb/kill-current-buffer)
(global-set-key (kbd "s-{") 'ptb/previous-buffer)
(global-set-key (kbd "s-}") 'ptb/next-buffer)
EOF

  cat << EOF > "${HOME}/.emacs.d/private/ptb/packages.el"
(setq ptb-packages '(adaptive-wrap auto-indent-mode))

(defun ptb/init-adaptive-wrap ()
  "Load the adaptive wrap package"
  (use-package adaptive-wrap
    :init
    (setq adaptive-wrap-extra-indent 2)
    :config
    (progn
      ;; http://stackoverflow.com/questions/13559061
      (when (fboundp 'adaptive-wrap-prefix-mode)
        (defun ptb/activate-adaptive-wrap-prefix-mode ()
          "Toggle 'visual-line-mode' and 'adaptive-wrap-prefix-mode' simultaneously."
          (adaptive-wrap-prefix-mode (if visual-line-mode 1 -1)))
        (add-hook 'visual-line-mode-hook 'ptb/activate-adaptive-wrap-prefix-mode)))))

(defun ptb/init-auto-indent-mode ()
  (use-package auto-indent-mode
    :init
    (setq
      auto-indent-delete-backward-char t
      auto-indent-fix-org-auto-fill t
      auto-indent-fix-org-move-beginning-of-line t
      auto-indent-fix-org-return t
      auto-indent-fix-org-yank t
      auto-indent-start-org-indent t
    )
  )
)
EOF
}

# Customize Finder

_finder='com.apple.finder	ShowHardDrivesOnDesktop	-bool	false	
com.apple.finder	ShowExternalHardDrivesOnDesktop	-bool	false	
com.apple.finder	ShowRemovableMediaOnDesktop	-bool	true	
com.apple.finder	ShowMountedServersOnDesktop	-bool	true	
com.apple.finder	NewWindowTarget	-string	PfLo	
com.apple.finder	NewWindowTargetPath	-string	file://${HOME}/Dropbox/	
-globalDomain	AppleShowAllExtensions	-bool	true	
com.apple.finder	FXEnableExtensionChangeWarning	-bool	false	
com.apple.finder	FXEnableRemoveFromICloudDriveWarning	-bool	true	
com.apple.finder	WarnOnEmptyTrash	-bool	false	
com.apple.finder	ShowPathbar	-bool	true	
com.apple.finder	ShowStatusBar	-bool	true	'

custom_finder () {
  config_defaults "${_finder}"
  defaults write "com.apple.finder" "NSToolbar Configuration Browser" \
    '{
      "TB Display Mode" = 2;
      "TB Item Identifiers" = (
        "com.apple.finder.BACK",
        "com.apple.finder.PATH",
        "com.apple.finder.SWCH",
        "com.apple.finder.ARNG",
        "NSToolbarFlexibleSpaceItem",
        "com.apple.finder.SRCH",
        "com.apple.finder.ACTN"
      );
    }'
}

# Customize getmail

_getmail_ini='destination	ignore_stderr	true
destination	type	MDA_external
options	delete	true
options	delivered_to	false
options	read_all	false
options	received	false
options	verbose	0
retriever	mailboxes	("[Gmail]/All Mail",)
retriever	move_on_delete	[Gmail]/Trash
retriever	port	993
retriever	server	imap.gmail.com
retriever	type	SimpleIMAPSSLRetriever'
_getmail_plist='add	:KeepAlive	bool	true
add	:ProcessType	string	Background
add	:ProgramArguments	array	
add	:ProgramArguments:0	string	/usr/local/bin/getmail
add	:ProgramArguments:1	string	--idle
add	:ProgramArguments:2	string	[Gmail]/All Mail
add	:ProgramArguments:3	string	--rcfile
add	:RunAtLoad	bool	true
add	:StandardOutPath	string	getmail.log
add	:StandardErrorPath	string	getmail.err'
custom_getmail () {
  test -d "${HOME}/.getmail" || \
    mkdir -m go= "${HOME}/.getmail"

  while true; do
    e=$(ask2 "To configure getmail, enter your email address." "Configure Getmail" "No More Addresses" "Create Configuration" "$(whoami)@$(hostname -f | cut -d. -f2-)" "false")
    test -n "$e" || break

    security find-internet-password -a "$e" -D "getmail password" > /dev/null || \
    p=$(ask2 "Enter your password for $e." "Configure Getmail" "Cancel" "Set Password" "" "true") && \
    security add-internet-password -a "$e" -s "imap.gmail.com" -r "imap" \
      -l "$e" -D "getmail password" -P 993 -w "$p"

    if which crudini > /dev/null; then
      gm="${HOME}/.getmail/${e}"
      printf "%s\n" "${_getmail_ini}" | \
      while IFS="$(printf '\t')" read section key value; do
        crudini --set "$gm" "$section" "$key" "$value"
      done
      crudini --set "$gm" "destination" "arguments" "('-c','/usr/local/etc/dovecot/dovecot.conf','-d','$(whoami)')"
      crudini --set "$gm" "destination" "path" "$(find '/usr/local/Cellar/dovecot' -name 'dovecot-lda' -print -quit)"
      crudini --set "$gm" "retriever" "username" "$e"
    fi

    la="${HOME}/Library/LaunchAgents/ca.pyropus.getmail.${e}"

    test -d "$(dirname $la)" || \
      mkdir -p "$(dirname $la)"
    launchctl unload "${la}.plist" 2> /dev/null
    rm -f "${la}.plist"

    config_plist "$_getmail_plist" "${la}.plist"
    config_defaults "$(printf "${la}\tLabel\t-string\tca.pyropus.getmail.${e}\t")"
    config_defaults "$(printf "${la}\tProgramArguments\t-array-add\t${e}\t")"
    config_defaults "$(printf "${la}\tWorkingDirectory\t-string\t${HOME}/.getmail\t")"

    plutil -convert xml1 "${la}.plist"
    launchctl load "${la}.plist" 2> /dev/null
  done
}

# Customize Git

custom_git () {
  if ! test -e "${HOME}/.gitconfig"; then
    true
  fi
}

# Customize GnuPG

custom_gnupg () {
  if ! test -d "${HOME}/.gnupg"; then
    true
  fi
}

# Customize iStat Menus

_istatmenus='com.bjango.istatmenus5.extras	MenubarSkinColor	-int	8	
com.bjango.istatmenus5.extras	MenubarTheme	-int	0	
com.bjango.istatmenus5.extras	DropdownTheme	-int	1	
com.bjango.istatmenus5.extras	CPU_MenubarMode	-string	100,2,0	
com.bjango.istatmenus5.extras	CPU_MenubarTextSize	-int	14	
com.bjango.istatmenus5.extras	CPU_MenubarGraphShowBackground	-int	0	
com.bjango.istatmenus5.extras	CPU_MenubarGraphWidth	-int	32	
com.bjango.istatmenus5.extras	CPU_MenubarGraphBreakdowns	-int	0	
com.bjango.istatmenus5.extras	CPU_MenubarGraphCustomColors	-int	0	
com.bjango.istatmenus5.extras	CPU_MenubarGraphOverall	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	CPU_MenubarCombineCores	-int	1	
com.bjango.istatmenus5.extras	CPU_MenubarGroupItems	-int	0	
com.bjango.istatmenus5.extras	CPU_MenubarSingleHistoryGraph	-int	0	
com.bjango.istatmenus5.extras	CPU_CombineLogicalCores	-int	1	
com.bjango.istatmenus5.extras	CPU_AppFormat	-int	0	
com.bjango.istatmenus5.extras	Memory_MenubarMode	-string	100,2,6	
com.bjango.istatmenus5.extras	Memory_MenubarPercentageSize	-int	14	
com.bjango.istatmenus5.extras	Memory_MenubarGraphBreakdowns	-int	1	
com.bjango.istatmenus5.extras	Memory_MenubarGraphCustomColors	-int	0	
com.bjango.istatmenus5.extras	Memory_MenubarGraphOverall	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	Memory_MenubarGraphWired	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	Memory_MenubarGraphActive	-string	0.47 0.67 0.47 1.00	
com.bjango.istatmenus5.extras	Memory_MenubarGraphCompressed	-string	0.53 0.73 0.53 1.00	
com.bjango.istatmenus5.extras	Memory_MenubarGraphInactive	-string	0.60 0.80 0.60 1.00	
com.bjango.istatmenus5.extras	Memory_IgnoreInactive	-int	0	
com.bjango.istatmenus5.extras	Memory_AppFormat	-int	0	
com.bjango.istatmenus5.extras	Memory_DisplayFormat	-int	1	
com.bjango.istatmenus5.extras	Disks_MenubarMode	-string	100,9,8	
com.bjango.istatmenus5.extras	Disks_MenubarGroupItems	-int	1	
com.bjango.istatmenus5.extras	Disks_MenubarRWShowLabel	-int	1	
com.bjango.istatmenus5.extras	Disks_MenubarRWBold	-int	0	
com.bjango.istatmenus5.extras	Disks_MenubarGraphActivityWidth	-int	32	
com.bjango.istatmenus5.extras	Disks_MenubarGraphActivityShowBackground	-int	0	
com.bjango.istatmenus5.extras	Disks_MenubarGraphActivityCustomColors	-int	0	
com.bjango.istatmenus5.extras	Disks_MenubarGraphActivityRead	-string	0.60 0.80 0.60 1.00	
com.bjango.istatmenus5.extras	Disks_MenubarGraphActivityWrite	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	Disks_SeperateFusion	-int	1	
com.bjango.istatmenus5.extras	Network_MenubarMode	-string	4,0,1	
com.bjango.istatmenus5.extras	Network_TextUploadColor-Dark	-string	1.00 1.00 1.00 1.00	
com.bjango.istatmenus5.extras	Network_TextDownloadColor-Dark	-string	1.00 1.00 1.00 1.00	
com.bjango.istatmenus5.extras	Network_GraphWidth	-int	32	
com.bjango.istatmenus5.extras	Network_GraphShowBackground	-int	0	
com.bjango.istatmenus5.extras	Network_GraphCustomColors	-int	0	
com.bjango.istatmenus5.extras	Network_GraphUpload	-string	0.60 0.80 0.60 1.00	
com.bjango.istatmenus5.extras	Network_GraphDownload	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	Network_GraphMode	-int	1	
com.bjango.istatmenus5.extras	Battery_MenubarMode	-string	5,0	
com.bjango.istatmenus5.extras	Battery_ColorGraphCustomColors	-int	1	
com.bjango.istatmenus5.extras	Battery_ColorGraphCharged	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	Battery_ColorGraphCharging	-string	0.60 0.80 0.60 1.00	
com.bjango.istatmenus5.extras	Battery_ColorGraphDraining	-string	1.00 0.60 0.60 1.00	
com.bjango.istatmenus5.extras	Battery_ColorGraphLow	-string	1.00 0.20 0.20 1.00	
com.bjango.istatmenus5.extras	Battery_PercentageSize	-int	14	
com.bjango.istatmenus5.extras	Battery_MenubarCustomizeStates	-int	0	
com.bjango.istatmenus5.extras	Battery_MenubarHideBluetooth	-int	1	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	EE	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	MMM	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	d	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	h	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	:	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	mm	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	:	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	ss	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	a	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	EE	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	h	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	:	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	mm	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	a	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	\\040\\050	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	zzz	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	\\051	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	4930956	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	4887398	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	5419384	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	5392171	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	5879400	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	5856195	
com.bjango.istatmenus5.extras	Time_TextSize	-int	14	'

custom_istatmenus () {
  defaults delete com.bjango.istatmenus5.extras Time_MenubarFormat > /dev/null 2>&1
  defaults delete com.bjango.istatmenus5.extras Time_DropdownFormat > /dev/null 2>&1
  defaults delete com.bjango.istatmenus5.extras Time_Cities > /dev/null 2>&1
  config_defaults "${_istatmenus}"
}

# Customize Meteorologist

_meteorologist='com.heat.meteorologist	controlsInSubmenu	-string	0	
com.heat.meteorologist	currentWeatherInSubmenu	-string	0	
com.heat.meteorologist	displayCityName	-string	0	
com.heat.meteorologist	displayHumidity	-string	0	
com.heat.meteorologist	displayWeatherIcon	-string	1	
com.heat.meteorologist	extendedForecastIcons	-string	1	
com.heat.meteorologist	extendedForecastInSubmenu	-string	0	
com.heat.meteorologist	extendedForecastSingleLine	-string	1	
com.heat.meteorologist	forecastDays	-int	8	
com.heat.meteorologist	viewExtendedForecast	-string	1	
com.heat.meteorologist	weatherSource_1	-int	3	'

custom_meteorologist () {
  config_defaults "${_meteorologist}"
}

# Customize Moom

_moom='com.manytricks.Moom	Allow For Drawers	-bool	true	
com.manytricks.Moom	Grid Spacing	-bool	true	
com.manytricks.Moom	Grid Spacing: Gap	-int	2	
com.manytricks.Moom	Grid Spacing: Apply To Edges	-bool	false	
com.manytricks.Moom	Target Window Highlight	-float	0.25	
com.manytricks.Moom	Stealth Mode	-bool	true	
com.manytricks.Moom	Application Mode	-int	2	
com.manytricks.Moom	Mouse Controls	-bool	true	
com.manytricks.Moom	Mouse Controls Delay	-float	0.1	
com.manytricks.Moom	Mouse Controls Grid	-bool	true	
com.manytricks.Moom	Mouse Controls Grid: Mode	-int	3	
com.manytricks.Moom	Mouse Controls Grid: Columns	-int	16	
com.manytricks.Moom	Mouse Controls Grid: Rows	-int	9	
com.manytricks.Moom	Mouse Controls Include Custom Controls	-bool	true	
com.manytricks.Moom	Mouse Controls Include Custom Controls: Show On Hover	-bool	false	
com.manytricks.Moom	Mouse Controls Auto-Activate Window	-bool	true	
com.manytricks.Moom	Snap	-bool	false	
com.manytricks.Moom	Custom Controls	-array-add	{ Action = 19; "Relative Frame" = "{{0, 0.5}, {0.375, 0.5}}"; }	
com.manytricks.Moom	Custom Controls	-array-add	{ Action = 19; "Relative Frame" = "{{0, 0}, {0.375, 0.5}}"; }	
com.manytricks.Moom	Custom Controls	-array-add	{ Action = 19; "Relative Frame" = "{{0, 0}, {0.375, 1}}"; }	
com.manytricks.Moom	Custom Controls	-array-add	{ Action = 19; "Relative Frame" = "{{0.125, 0}, {0.25, 0.33333}}"; }	
com.manytricks.Moom	Custom Controls	-array-add	{ Action = 19; "Relative Frame" = "{{0.375, 0.33333}, {0.3125, 0.66666}}"; }	
com.manytricks.Moom	Custom Controls	-array-add	{ Action = 19; "Relative Frame" = "{{0.375, 0}, {0.3125, 0.33333}}"; }	
com.manytricks.Moom	Custom Controls	-array-add	{ Action = 19; "Relative Frame" = "{{0.6875, 0.66666}, {0.3125, 0.66666}}"; }	
com.manytricks.Moom	Custom Controls	-array-add	{ Action = 19; "Relative Frame" = "{{0.6875, 0.33333}, {0.3125, 0.33333}}"; }	
com.manytricks.Moom	Custom Controls	-array-add	{ Action = 19; "Relative Frame" = "{{0.6875, 0}, {0.3125, 0.33333}}"; }	
com.manytricks.Moom	Custom Controls	-array-add	{ Action = 1001; "Apply to Overlapping Windows" = 1; Snapshot = ({ "Application Name" = Safari; "Bundle Identifier" = "com.apple.safari"; "Window Frame" = "{{0, 890}, {1199, 888}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = Chrome; "Bundle Identifier" = "com.google.chrome"; "Window Frame" = "{{0, 0}, {1199, 888}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = Firefox; "Bundle Identifier" = "org.mozilla.firefox"; "Window Frame" = "{{0, 0}, {1199, 888}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = Emacs; "Bundle Identifier" = "org.gnu.emacs"; "Window Frame" = "{{1201, 597}, {991, 1181}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = Code; "Bundle Identifier" = "com.microsoft.vscode"; "Window Frame" = "{{1201, 594}, {1999, 1184}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = Mail; "Bundle Identifier" = "com.apple.mail"; "Window Frame" = "{{2201, 594}, {999, 1184}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = nvALT; "Bundle Identifier" = "net.elasticthreads.nv"; "Window Frame" = "{{2201, 989}, {999, 789}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = SimpleNote; "Bundle Identifier" = "bogdanf.osx.metanota.pro"; "Window Frame" = "{{2201, 989}, {999, 789}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = Finder; "Bundle Identifier" = "com.apple.finder"; "Window Frame" = "{{2401, 1186}, {799, 592}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = Messages; "Bundle Identifier" = "com.apple.ichat"; "Window Frame" = "{{401, 0}, {798, 591}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = Slack; "Bundle Identifier" = "com.tinyspeck.slackmacgap"; "Window Frame" = "{{0, 0}, {999, 591}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = Terminal; "Bundle Identifier" = "com.apple.terminal"; "Window Frame" = "{{1201, 20}, {993, 572}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = iTerm2; "Bundle Identifier" = "com.googlecode.iterm2"; "Window Frame" = "{{1201, 17}, {993, 572}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = QuickTime; "Bundle Identifier" = "com.apple.quicktimeplayerx"; "Window Frame" = "{{2201, 0}, {999, 592}}"; "Window Subrole" = AXStandardWindow; }, { "Application Name" = VLC; "Bundle Identifier" = "org.videolan.vlc"; "Window Frame" = "{{2201, 0}, {999, 592}}"; "Window Subrole" = AXStandardWindow; }); "Snapshot Screens" = ( "{{0, 0}, {3200, 1800}}" ); }	
com.manytricks.Moom	Configuration Grid: Columns	-int	16	
com.manytricks.Moom	Configuration Grid: Rows	-int	9	
com.manytricks.Moom	SUEnableAutomaticChecks	-bool	true	'

custom_moom () {
  killall Moom > /dev/null 2>&1
  defaults delete com.manytricks.Moom "Custom Controls" > /dev/null 2>&1
  config_defaults "${_moom}"
  test -d "/Applications/Moom.app" && \
    open "/Applications/Moom.app"
}

# Customize MP4 Automator

_mp4_automator='MP4	aac_adtstoasc	True
MP4	audio-channel-bitrate	256
MP4	audio-codec	ac3,aac
MP4	audio-default-language	eng
MP4	audio-filter	
MP4	audio-language	eng
MP4	convert-mp4	True
MP4	copy_to	
MP4	delete_original	False
MP4	download-artwork	Poster
MP4	download-subs	True
MP4	embed-subs	True
MP4	ffmpeg	/usr/local/bin/ffmpeg
MP4	ffprobe	/usr/local/bin/ffprobe
MP4	fullpathguess	True
MP4	h264-max-level	4.1
MP4	ios-audio	True
MP4	ios-audio-filter	
MP4	ios-first-track-only	True
MP4	max-audio-channels	
MP4	move_to	
MP4	output_directory	
MP4	output_extension	m4v
MP4	output_format	mp4
MP4	permissions	644
MP4	pix-fmt	
MP4	post-process	False
MP4	postopts	
MP4	preopts	
MP4	relocate_moov	True
MP4	sub-providers	addic7ed,podnapisi,thesubdb,opensubtitles
MP4	subtitle-codec	mov_text
MP4	subtitle-default-language	eng
MP4	subtitle-encoding	
MP4	subtitle-language	eng
MP4	tag-language	eng
MP4	tagfile	True
MP4	threads	auto
MP4	use-qsv-decoder-with-encoder	True
MP4	video-bitrate	
MP4	video-codec	h264,x264
MP4	video-crf	
MP4	video-max-width	1920
Plex	host	localhost
Plex	port	32400
Plex	refresh	False
Plex	token	
Radarr	host	localhost
Radarr	port	7878
Radarr	ssl	False
Radarr	web_root	
Sonarr	host	localhost
Sonarr	port	8989
Sonarr	ssl	False
Sonarr	web_root	'

custom_mp4_automator () {
  mkdir -p "${HOME}/.config/mp4_automator" && \
  curl --compressed --location --silent \
    "https://github.com/mdhiggins/sickbeard_mp4_automator/archive/master.tar.gz" | \
  tar -C "${HOME}/.config/mp4_automator" --strip-components 1 -xf -
  printf "%s\n" "2.7.13" > "${HOME}/.config/mp4_automator/.python-version"

  if which crudini > /dev/null; then
    printf "%s\n" "${_mp4_automator}" | \
    while IFS="$(printf '\t')" read section key value; do
      crudini --set "${HOME}/.config/mp4_automator/autoProcess.ini" "${section}" "${key}" "${value}"
    done

    open "http://localhost:7878/settings/general"
    RADARRAPI="$(ask 'Radarr API Key?' 'Set API Key' '')"
    crudini --set "${HOME}/.config/mp4_automator/autoProcess.ini" "Radarr" "apikey" "$RADARRAPI"

    open "http://localhost:8989/settings/general"
    SONARRAPI="$(ask 'Sonarr API Key?' 'Set API Key' '')"
    crudini --set "${HOME}/.config/mp4_automator/autoProcess.ini" "Sonarr" "apikey" "$SONARRAPI"
  fi

  find "${HOME}/.config/mp4_automator" -name "*.py" -print0 | \
    xargs -0 -L 1 sed -i "" -e "s:/usr/bin/env python:/usr/local/python/versions/2.7.13/bin/python:"
}

# Customize nvALT

_nvalt='net.elasticthreads.nv	TableFontPointSize	-int	11	
net.elasticthreads.nv	AppActivationKeyCode	-int	-1	
net.elasticthreads.nv	AppActivationModifiers	-int	-1	
net.elasticthreads.nv	AutoCompleteSearches	-bool	true	
net.elasticthreads.nv	ConfirmNoteDeletion	-bool	true	
net.elasticthreads.nv	QuitWhenClosingMainWindow	-bool	false	
net.elasticthreads.nv	StatusBarItem	-bool	true	
net.elasticthreads.nv	ShowDockIcon	-bool	false	
net.elasticthreads.nv	PastePreservesStyle	-bool	false	
net.elasticthreads.nv	CheckSpellingInNoteBody	-bool	false	
net.elasticthreads.nv	TabKeyIndents	-bool	true	
net.elasticthreads.nv	UseSoftTabs	-bool	true	
net.elasticthreads.nv	MakeURLsClickable	-bool	true	
net.elasticthreads.nv	AutoSuggestLinks	-bool	false	
net.elasticthreads.nv	UseMarkdownImport	-bool	false	
net.elasticthreads.nv	UseReadability	-bool	false	
net.elasticthreads.nv	rtl	-bool	false	
net.elasticthreads.nv	UseAutoPairing	-bool	true	
net.elasticthreads.nv	DefaultEEIdentifier	-string	org.gnu.Emacs	
net.elasticthreads.nv	UserEEIdentifiers	-array-add	com.apple.TextEdit	
net.elasticthreads.nv	UserEEIdentifiers	-array-add	org.gnu.Emacs	
net.elasticthreads.nv	NoteBodyFont	-data	040b73747265616d747970656481e803840140848484064e53466f6e741e8484084e534f626a65637400858401692884055b3430635d060000001e000000fffe49006e0063006f006e0073006f006c006100740061004c004700430000008401660d8401630098019800980086	
net.elasticthreads.nv	HighlightSearchTerms	-bool	true	
net.elasticthreads.nv	SearchTermHighlightColor	-data	040b73747265616d747970656481e803840140848484074e53436f6c6f72008484084e534f626a65637400858401630184046666666683cdcc4c3f0183cdcc4c3f0186	
net.elasticthreads.nv	ForegroundTextColor	-data	040b73747265616d747970656481e803840140848484074e53436f6c6f72008484084e534f626a65637400858401630184046666666683cdcc4c3f83cdcc4c3f83cdcc4c3f0186	
net.elasticthreads.nv	BackgroundTextColor	-data	040b73747265616d747970656481e803840140848484074e53436f6c6f72008484084e534f626a65637400858401630184046666666683d1d0d03d83d1d0d03d83d1d0d03d0186	
net.elasticthreads.nv	ShowGrid	-bool	true	
net.elasticthreads.nv	AlternatingRows	-bool	true	
net.elasticthreads.nv	UseETScrollbarsOnLion	-bool	false	
net.elasticthreads.nv	KeepsMaxTextWidth	-bool	true	
net.elasticthreads.nv	NoteBodyMaxWidth	-int	650	
net.elasticthreads.nv	HorizontalLayout	-bool	true	
net.elasticthreads.nv	NoteAttributesVisible	-array-add	Title	
net.elasticthreads.nv	NoteAttributesVisible	-array-add	Tags	
net.elasticthreads.nv	TableIsReverseSorted	-bool	true	
net.elasticthreads.nv	TableSortColumn	-string	Date Modified	
net.elasticthreads.nv	TableColumnsHaveBodyPreview	-bool	true	'
_nvalt_launchd='add	:KeepAlive	bool	true
add	:Label	string	net.elasticthreads.nv
add	:ProcessType	string	Interactive
add	:Program	string	/Applications/nvALT.app/Contents/MacOS/nvALT
add	:RunAtLoad	bool	true'

custom_nvalt () {
  config_defaults "$_nvalt"
  config_launchd "${HOME}/Library/LaunchAgents/net.elasticthreads.nv.plist" "$_nvalt_launchd"
}

# Customize NZBGet

# - $7.50/mth: http://www.news.astraweb.com/specials/2mospecial.html
# - €13/100GB: https://www.tweaknews.eu/en/usenet-plans
# - $17/100GB: https://www.newsdemon.com/usenet-access.php
# - $20/200GB: https://billing.blocknews.net/signup.php


_nzbget='ControlIP	127.0.0.1
ControlPort	6789
AuthorizedIP	127.0.0.1
Server1.Level	0
Server1.Host	ssl.astraweb.com
Server1.Port	443
Server1.Encryption	yes
Server1.Connections	6
Server1.Retention	3000
Server2.Level	0
Server2.Host	ssl-us.astraweb.com
Server2.Port	443
Server2.Encryption	yes
Server2.Connections	6
Server2.Retention	3000
Server3.Level	0
Server3.Host	ssl-eu.astraweb.com
Server3.Port	443
Server3.Encryption	yes
Server3.Connections	6
Server3.Retention	3000
Server4.Level	1
Server4.Host	news.tweaknews.eu
Server4.Port	443
Server4.Encryption	yes
Server4.Connections	40
Server4.Retention	2500
Server5.Level	2
Server5.Host	news.newsdemon.com
Server5.Port	563
Server5.Encryption	yes
Server5.Connections	12
Server5.Retention	3303
Server6.Level	2
Server6.Host	us.newsdemon.com
Server6.Port	563
Server6.Encryption	yes
Server6.Connections	12
Server6.Retention	3303
Server7.Level	2
Server7.Host	eu.newsdemon.com
Server7.Port	563
Server7.Encryption	yes
Server7.Connections	12
Server7.Retention	3303
Server8.Level	2
Server8.Host	nl.newsdemon.com
Server8.Port	563
Server8.Encryption	yes
Server8.Connections	12
Server8.Retention	3303
Server9.Level	2
Server9.Host	usnews.blocknews.net
Server9.Port	443
Server9.Encryption	yes
Server9.Connections	16
Server9.Retention	3240
Server10.Level	2
Server10.Host	eunews.blocknews.net
Server10.Port	443
Server10.Encryption	yes
Server10.Connections	16
Server10.Retention	3240
Server11.Level	2
Server11.Host	eunews2.blocknews.net
Server11.Port	443
Server11.Encryption	yes
Server11.Connections	16
Server11.Retention	3240'

custom_nzbget () {
  f="${HOME}/Library/Application Support/NZBGet/nzbget.conf"
  mkdir -p "$(dirname $f)"
  if which crudini > /dev/null; then
    printf "%s\n" "${_nzbget}" | \
    while IFS="$(printf '\t')" read key value; do
      crudini --set "$f" "" "${key}" "${value}"
    done
  fi
  sed -i "" -e "s/ = /=/g" "$f"
}

# Customize Safari

_safari='com.apple.Safari	AlwaysRestoreSessionAtLaunch	-bool	false	
com.apple.Safari	OpenPrivateWindowWhenNotRestoringSessionAtLaunch	-bool	false	
com.apple.Safari	NewWindowBehavior	-int	1	
com.apple.Safari	NewTabBehavior	-int	1	
com.apple.Safari	AutoOpenSafeDownloads	-bool	false	
com.apple.Safari	TabCreationPolicy	-int	2	
com.apple.Safari	AutoFillFromAddressBook	-bool	false	
com.apple.Safari	AutoFillPasswords	-bool	true	
com.apple.Safari	AutoFillCreditCardData	-bool	false	
com.apple.Safari	AutoFillMiscellaneousForms	-bool	false	
com.apple.Safari	SuppressSearchSuggestions	-bool	false	
com.apple.Safari	UniversalSearchEnabled	-bool	false	
com.apple.Safari	WebsiteSpecificSearchEnabled	-bool	true	
com.apple.Safari	PreloadTopHit	-bool	true	
com.apple.Safari	ShowFavoritesUnderSmartSearchField	-bool	false	
com.apple.Safari	SafariGeolocationPermissionPolicy	-int	0	
com.apple.Safari	BlockStoragePolicy	-int	2	
com.apple.Safari	WebKitStorageBlockingPolicy	-int	1	
com.apple.Safari	com.apple.Safari.ContentPageGroupIdentifier.WebKit2StorageBlockingPolicy	-int	1	
com.apple.Safari	SendDoNotTrackHTTPHeader	-bool	true	
com.apple.WebFoundation	NSHTTPAcceptCookies	-string	always	
com.apple.Safari	com.apple.Safari.ContentPageGroupIdentifier.WebKit2ApplePayCapabilityDisclosureAllowed	-bool	true	
com.apple.Safari	CanPromptForPushNotifications	-bool	false	
com.apple.Safari	ShowFullURLInSmartSearchField	-bool	true	
com.apple.Safari	WebKitDefaultTextEncodingName	-string	utf-8	
com.apple.Safari	com.apple.Safari.ContentPageGroupIdentifier.WebKit2DefaultTextEncodingName	-string	utf-8	
com.apple.Safari	IncludeDevelopMenu	-bool	true	
com.apple.Safari	WebKitDeveloperExtrasEnabledPreferenceKey	-bool	true	
com.apple.Safari	com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled	-bool	true	
com.apple.Safari	ShowFavoritesBar-v2	-bool	true	
com.apple.Safari	AlwaysShowTabBar	-bool	true	
com.apple.Safari	ShowStatusBar	-bool	true	
com.apple.Safari	ShowStatusBarInFullScreen	-bool	true	'

custom_safari () {
  config_defaults "${_safari}"
}

# Customize Sieve

custom_sieve () {
  cat > "${HOME}/.sieve" << EOF
require ["date", "fileinto", "imap4flags", "mailbox", "relational", "variables"];

setflag "\\\\Seen";

if date :is "date" "year" "1995" { fileinto :create "Archives.1995"; }
if date :is "date" "year" "1996" { fileinto :create "Archives.1996"; }
if date :is "date" "year" "1997" { fileinto :create "Archives.1997"; }
if date :is "date" "year" "1998" { fileinto :create "Archives.1998"; }
if date :is "date" "year" "1999" { fileinto :create "Archives.1999"; }
if date :is "date" "year" "2000" { fileinto :create "Archives.2000"; }
if date :is "date" "year" "2001" { fileinto :create "Archives.2001"; }
if date :is "date" "year" "2002" { fileinto :create "Archives.2002"; }
if date :is "date" "year" "2003" { fileinto :create "Archives.2003"; }
if date :is "date" "year" "2004" { fileinto :create "Archives.2004"; }
if date :is "date" "year" "2005" { fileinto :create "Archives.2005"; }
if date :is "date" "year" "2006" { fileinto :create "Archives.2006"; }
if date :is "date" "year" "2007" { fileinto :create "Archives.2007"; }
if date :is "date" "year" "2008" { fileinto :create "Archives.2008"; }
if date :is "date" "year" "2009" { fileinto :create "Archives.2009"; }
if date :is "date" "year" "2010" { fileinto :create "Archives.2010"; }
if date :is "date" "year" "2011" { fileinto :create "Archives.2011"; }
if date :is "date" "year" "2012" { fileinto :create "Archives.2012"; }
if date :is "date" "year" "2013" { fileinto :create "Archives.2013"; }
if date :is "date" "year" "2014" { fileinto :create "Archives.2014"; }
if date :is "date" "year" "2015" { fileinto :create "Archives.2015"; }
if date :is "date" "year" "2016" { fileinto :create "Archives.2016"; }
if date :is "date" "year" "2017" { fileinto :create "Archives.2017"; }
if date :is "date" "year" "2018" { fileinto :create "Archives.2018"; }
if date :is "date" "year" "2019" { fileinto :create "Archives.2019"; }
if date :is "date" "year" "2020" { fileinto :create "Archives.2020"; }
EOF
}

# Customize Sonarr

_sonarr='Advanced Settings	Shown
Rename Episodes	Yes
Standard Episode Format	{Series Title} - s{season:00}e{episode:00} - {Episode Title}
Daily Episode Format	{Series Title} - {Air-Date} - {Episode Title}
Anime Episode Format	{Series Title} - s{season:00}e{episode:00} - {Episode Title}
Multi-Episode Style	Scene
Create empty series folders	Yes
Ignore Deleted Episodes	Yes
Change File Date	UTC Air Date
Set Permissions	Yes
Download Clients	NZBGet
NZBGet: Name	NZBGet
NZBGet: Category	Sonarr
Failed: Remove	No
Drone Factory Interval	0
Connect: Custom Script	
postSonarr: Name	postSonarr
postSonarr: On Grab	No
postSonarr: On Download	Yes
postSonarr: On Upgrade	Yes
postSonarr: On Rename	No
postSonarr: Path	${HOME}/.config/mp4_automator/postSonarr.py
Start-Up: Open browser on start	No
Security: Authentication	Basic (Browser popup)'

custom_sonarr () {
  open "http://localhost:7878/settings/mediamanagement"
  open "http://localhost:8989/settings/mediamanagement"
  printf "%s" "$_sonarr" | \
  while IFS="$(printf '\t')" read pref value; do
    printf "\033[1m\033[34m%s:\033[0m %s\n" "$pref" "$value"
  done
}

# Customize SSH

custom_ssh () {
  if ! test -d "${HOME}/.ssh"; then
    mkdir -m go= "${HOME}/.ssh"
    e="$(ask 'New SSH Key: Email Address?' 'OK' '')"
    ssh-keygen -t ed25519 -a 100 -C "$e"
    cat << EOF > "${HOME}/.ssh/config"
Host *
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
EOF
    pbcopy < "${HOME}/.ssh/id_ed25519.pub"
    open "https://github.com/settings/keys"
  fi
}

# Customize System Preferences

custom_sysprefs () {
  custom_general
  custom_desktop "/Library/Desktop Pictures/Solid Colors/Solid Black.png"
  custom_screensaver
  custom_dock
  custom_dockapps
  # custom_security
  custom_text
  custom_dictation
  custom_mouse
  custom_trackpad
  custom_sound
  custom_loginitems
  custom_siri
  custom_clock
  custom_a11y
  custom_other
}

# Customize General

_general='-globalDomain	AppleAquaColorVariant	-int	6	
-globalDomain	AppleInterfaceStyle	-string	Dark	
-globalDomain	_HIHideMenuBar	-bool	false	
-globalDomain	AppleHighlightColor	-string	0.600000 0.800000 0.600000	
-globalDomain	NSTableViewDefaultSizeMode	-int	1	
-globalDomain	AppleShowScrollBars	-string	Always	
-globalDomain	AppleScrollerPagingBehavior	-bool	false	
-globalDomain	NSCloseAlwaysConfirmsChanges	-bool	true	
-globalDomain	NSQuitAlwaysKeepsWindows	-bool	false	
com.apple.coreservices.useractivityd	ActivityAdvertisingAllowed	-bool	true	-currentHost
com.apple.coreservices.useractivityd	ActivityReceivingAllowed	-bool	true	-currentHost
-globalDomain	AppleFontSmoothing	-int	1	-currentHost'

custom_general () {
  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
  config_defaults "${_general}"
  osascript << EOF
    tell application "System Events"
      tell appearance preferences
        set recent documents limit to 0
        set recent applications limit to 0
        set recent servers limit to 0
      end tell
    end tell
EOF
}

# Customize Desktop Picture

custom_desktop () {
  osascript - "${1}" << EOF 2> /dev/null
    on run { _this }
      tell app "System Events" to set picture of every desktop to POSIX file _this
    end run
EOF
}

# Customize Screen Saver

_screensaver='com.apple.screensaver	idleTime	-int	0	-currentHost
com.apple.dock	wvous-tl-corner	-int	2	
com.apple.dock	wvous-tl-modifier	-int	1048576	
com.apple.dock	wvous-bl-corner	-int	10	
com.apple.dock	wvous-bl-modifier	-int	0	'

custom_screensaver () {
  if test -e "/Library/Screen Savers/BlankScreen.saver"; then
    defaults -currentHost write com.apple.screensaver moduleDict \
      '{
        moduleName = "BlankScreen";
        path = "/Library/Screen Savers/BlankScreen.saver";
        type = 0;
      }'
  fi
  config_defaults "${_screensaver}"
}

# Customize Dock

_dock='com.apple.dock	tilesize	-int	32	
com.apple.dock	magnification	-bool	false	
com.apple.dock	largesize	-int	64	
com.apple.dock	orientation	-string	right	
com.apple.dock	mineffect	-string	scale	
-globalDomain	AppleWindowTabbingMode	-string	always	
-globalDomain	AppleActionOnDoubleClick	-string	None	
com.apple.dock	minimize-to-application	-bool	true	
com.apple.dock	launchanim	-bool	false	
com.apple.dock	autohide	-bool	true	
com.apple.dock	show-process-indicators	-bool	true	'

custom_dock () {
  config_defaults "${_dock}"
}

# Customize Dock Apps

_dockapps='Metanota Pro
Mail
Safari
Messages
Emacs
BBEdit
Atom
Utilities/Terminal
iTerm
System Preferences
PCalc
Hermes
iTunes
VLC'

custom_dockapps () {
  defaults write com.apple.dock "autohide-delay" -float 0
  defaults write com.apple.dock "autohide-time-modifier" -float 0.5

  defaults delete com.apple.dock "persistent-apps"

  printf "%s\n" "${_dockapps}" | \
  while IFS="$(printf '\t')" read app; do
    if test -e "/Applications/${app}.app"; then
      defaults write com.apple.dock "persistent-apps" -array-add \
        "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/${app}.app/</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    fi
  done

  defaults delete com.apple.dock "persistent-others"

  osascript -e 'tell app "Dock" to quit'
}

# Customize Security

_security='com.apple.screensaver	askForPassword	-int	1	
com.apple.screensaver	askForPasswordDelay	-int	5	'

custom_security () {
  config_defaults "${_security}"
}

# Customize Text

_text='-globalDomain	NSAutomaticCapitalizationEnabled	-bool	false	
-globalDomain	NSAutomaticPeriodSubstitutionEnabled	-bool	false	
-globalDomain	NSAutomaticQuoteSubstitutionEnabled	-bool	false	'
custom_text () {
  config_defaults "${_text}"
}

# Customize Dictation

_dictation='com.apple.speech.recognition.AppleSpeechRecognition.prefs	DictationIMMasterDictationEnabled	-bool	true	'

custom_dictation () {
  config_defaults "${_dictation}"
}

# Customize Mouse

_mouse='-globalDomain	com.apple.swipescrolldirection	-bool	false	'

custom_mouse () {
  config_defaults "${_mouse}"
}

# Customize Trackpad

_trackpad='com.apple.driver.AppleBluetoothMultitouch.trackpad	Clicking	-bool	true	
-globalDomain	com.apple.mouse.tapBehavior	-int	1	-currentHost'

custom_trackpad () {
  config_defaults "${_trackpad}"
}

# Customize Sound

_sound='-globalDomain	com.apple.sound.beep.sound	-string	/System/Library/Sounds/Sosumi.aiff	
-globalDomain	com.apple.sound.uiaudio.enabled	-int	0	
-globalDomain	com.apple.sound.beep.feedback	-int	0	'

custom_sound () {
  config_defaults "${_sound}"
}

# Customize Login Items

_loginitems='/Applications/Alfred 3.app
/Applications/autoping.app
/Applications/Caffeine.app
/Applications/Coffitivity.app
/Applications/Dropbox.app
/Applications/HardwareGrowler.app
/Applications/I Love Stars.app
/Applications/IPMenulet.app
/Applications/iTunes.app/Contents/MacOS/iTunesHelper.app
/Applications/Menubar Countdown.app
/Applications/Meteorologist.app
/Applications/Moom.app
/Applications/NZBGet.app
/Applications/Plex Media Server.app
/Applications/Radarr.app
/Applications/Sonarr-Menu.app
/Library/PreferencePanes/SteerMouse.prefPane/Contents/MacOS/SteerMouse Manager.app'
custom_loginitems () {
  printf "%s\n" "${_loginitems}" | \
  while IFS="$(printf '\t')" read app; do
    if test -e "$app"; then
      osascript - "$app" << EOF > /dev/null
        on run { _app }
          tell app "System Events"
            make new login item with properties { hidden: true, path: _app }
          end tell
        end run
EOF
    fi
  done
}

# Customize Siri

custom_siri () {
  defaults write com.apple.assistant.backedup "Output Voice" \
    '{
      Custom = 1;
      Footprint = 0;
      Gender = 1;
      Language = "en-US";
    }'
  defaults write com.apple.Siri StatusMenuVisible -bool false
}

# Customize Clock

custom_clock () {
  defaults -currentHost write com.apple.systemuiserver dontAutoLoad \
    -array-add "/System/Library/CoreServices/Menu Extras/Clock.menu"
  defaults write com.apple.menuextra.clock DateFormat \
    -string "EEE MMM d  h:mm:ss a"
}

# Customize Accessibility

_a11y='com.apple.universalaccess	reduceTransparency	-bool	true	'
_speech='com.apple.speech.voice.prefs	SelectedVoiceName	-string	Allison	
com.apple.speech.voice.prefs	SelectedVoiceCreator	-int	1886745202	
com.apple.speech.voice.prefs	SelectedVoiceID	-int	184555197	'

custom_a11y () {
  config_defaults "${_a11y}"

  if test -d "/System/Library/Speech/Voices/Allison.SpeechVoice"; then
    config_defaults "${_speech}"
    defaults write com.apple.speech.voice.prefs VisibleIdentifiers \
      '{
        "com.apple.speech.synthesis.voice.allison.premium" = 1;
      }'
  fi
}

# Customize Other Prefs

_other_prefs='Security & Privacy	General	com.apple.preference.security	General	/System/Library/PreferencePanes/Security.prefPane/Contents/Resources/FileVault.icns
Security & Privacy	FileVault	com.apple.preference.security	FDE	/System/Library/PreferencePanes/Security.prefPane/Contents/Resources/FileVault.icns
Security & Privacy	Accessibility	com.apple.preference.security	Privacy_Accessibility	/System/Library/PreferencePanes/Security.prefPane/Contents/Resources/FileVault.icns
Displays	Display	com.apple.preference.displays	displaysDisplayTab	/System/Library/PreferencePanes/Displays.prefPane/Contents/Resources/Displays.icns
Keyboard	Modifer Keys	com.apple.preference.keyboard	keyboardTab_ModifierKeys	/System/Library/PreferencePanes/Keyboard.prefPane/Contents/Resources/Keyboard.icns
Keyboard	Text	com.apple.preference.keyboard	Text	/System/Library/PreferencePanes/Keyboard.prefPane/Contents/Resources/Keyboard.icns
Keyboard	Shortcuts	com.apple.preference.keyboard	shortcutsTab	/System/Library/PreferencePanes/Keyboard.prefPane/Contents/Resources/Keyboard.icns
Keyboard	Dictation	com.apple.preference.keyboard	Dictation	/System/Library/PreferencePanes/Keyboard.prefPane/Contents/Resources/Keyboard.icns
Printers & Scanners	Main	com.apple.preference.printfax	print	/System/Library/PreferencePanes/PrintAndScan.prefPane/Contents/Resources/PrintScanPref.icns
Internet Accounts	Main	com.apple.preferences.internetaccounts	InternetAccounts	/System/Library/PreferencePanes/iCloudPref.prefPane/Contents/Resources/iCloud.icns
Network	Wi-Fi	com.apple.preference.network	Wi-Fi	/System/Library/PreferencePanes/Network.prefPane/Contents/Resources/Network.icns
Users & Groups	Login Options	com.apple.preferences.users	loginOptionsPref	/System/Library/PreferencePanes/Accounts.prefPane/Contents/Resources/AccountsPref.icns
Time Machine	Main	com.apple.prefs.backup	main	/System/Library/PreferencePanes/TimeMachine.prefPane/Contents/Resources/TimeMachine.icns'
custom_other () {
  T=$(printf '\t')
  printf "%s\n" "$_other_prefs" | \
  while IFS="$T" read pane anchor paneid anchorid icon; do
    osascript - "$pane" "$anchor" "$paneid" "$anchorid" "$icon" << EOF 2> /dev/null
  on run { _pane, _anchor, _paneid, _anchorid, _icon }
    tell app "System Events"
      display dialog "Open the " & _anchor & " pane of " & _pane & " preferences." buttons { "Open " & _pane } default button 1 with icon POSIX file _icon
    end tell
    tell app "System Preferences"
      if not running then run
      reveal anchor _anchorid of pane id _paneid
      activate
    end tell
  end run
EOF
  done
}


# Customize Vim

custom_vim () {
  true
}


# Log Out Then Log Back In

personalize_logout () {
  /usr/bin/read -n 1 -p "Press any key to continue.
" -s
  if run "Log Out Then Log Back In?" "Cancel" "Log Out"; then
    osascript -e 'tell app "loginwindow" to «event aevtrlgo»'
  fi
}
