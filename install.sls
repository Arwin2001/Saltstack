install_epel_repo:
  pkg.installed:
    - names
      - https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    - sources:
      - epel: https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

install_packages:
  pkg.installed:
    - names:
      - epel-release
      - yum-utils
      - unzip
      - curl
      - wget
      - bash-completion
      - policycoreutils-python-utils
      - mlocate
      - bzip2

install_apache:
  pkg.installed:
    - name: httpd
  file.managed:
    - name: /etc/httpd/conf.d/nextcloud.conf
    - source: salt://nexcloudphp.conf
    - template: jinja

enable_and_start_apache:
  service.running:
    - name: httpd
    - enable: True

configure_firewall:
  firewalld.present:
    - name: http
    - permanent: True
  cmd.run:
    - name: firewall-cmd --reload

enable_php_module:
  cmd.run:
    - name: dnf module enable php:8.0 -y

install_php:
  pkg.installed:
    - pkgs:
      - php
      - php-gd
      - php-intl
      - php-pecl-apcu
      - php-mysqlnd
      - php-pecl-zip

install_mariadb:
  pkg.installed:
    - pkgs:
      - mariadb
      - mariadb-server
      - python3-PyMySQL
  service.running:
    - name: mariadb
    - enable: True

create_database_and_user:
  mysql_database.present:
    - name: NextCloud_db
  mysql_user.present:
    - name: dbuser
    - host: localhost
    - password: Pa$$w0rd!
  mysql_grants.present:
    - grant: ALL
    - database: NextCloud_db
    - user: dbuser
  cmd.run:
    - name: "mysql -u root -p -e 'FLUSH PRIVILEGES;'"

install_and_start_redis:
  pkg.installed:
    - name: redis
  service.running:
    - name: redis
    - enable: True

download_nextcloud:
  archive.extracted:
    - name: /var/www/html/
    - source: https://download.nextcloud.com/server/releases/latest.tar.bz2
    - skip_verify: True
  cmd.run:
    - name: "mkdir /var/www/html/nextcloud/data"
    - require:
      - archive: download_nextcloud
    - onchanges:
      - archive: download_nextcloud

set_ownership_and_restart_apache:
  cmd.run:
    - name: "chown -R apache:apache /var/www/html/nextcloud"
    - onchanges:
      - cmd: download_nextcloud
  service.running:
    - name: httpd
    - watch:
      - cmd: set_ownership_and_restart_apache

set_selinux_policies_and_booleans:
  selinux.fcontext_policy_present:
    - name: /var/www/html/nextcloud/
    - sel_type: httpd_sys_rw_content_t
  cmd.run:
    - name: "restorecon -R /var/www/html/nextcloud/"
  selinux.boolean:
    - name: httpd_can_network_connect
    - value: on
  cmd.run:
    - name: "semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/data(/.*)?'"
    - watch:
      - cmd: set_selinux_policies_and_booleans
  cmd.run:
    - name: "semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/config(/.*)?'"
    - watch:
      - cmd: set_selinux_policies_and_booleans
  cmd.run:
    - name: "semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/apps(/.*)?'"
    - watch:
      - cmd: set_selinux_policies_and_booleans
  cmd.run:
    - name: "semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/.htaccess'"
    - watch:
      - cmd: set_selinux_policies_and_booleans
  cmd.run:
    - name: "semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/.user.ini'"
    - watch:
      - cmd: set_selinux_policies_and_booleans
  cmd.run:
    - name: "semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/3rdparty/aws/aws-sdk-php/src/data/logs(/.*)?'"
    - watch:
      - cmd: set_selinux_policies_and_booleans
  cmd.run:
    - name: "restorecon -R '/var/www/html/nextcloud/'"
    - watch:
      - cmd: set_selinux_policies_and_booleans

selinux_states:
  - selinux.fcontext_policy_present
  - selinux.boolean

apply_states:
  - install_epel_repo
  - install_packages
  - install_apache
  - enable_and_start_apache
  - configure_firewall
  - enable_php_module
  - install_php
  - install_mariadb
  - create_database_and_user
  - install_and_start_redis
  - download_nextcloud
  - set_ownership_and_restart_apache
  - set_selinux_policies_and_booleans

