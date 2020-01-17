#Package.logstash init.sls
{% set logstash = pillar['logstash'] %}

install openjdk-8-jre:
  pkg.installed:
    - name: openjdk-8-jre

add logstash repo:
  pkgrepo.managed:
    - humanname: Logstash Repo {{ logstash['repo'] }}
    - name: deb https://artifacts.elastic.co/packages/{{ logstash['repo'] }}/apt stable main
    - file: /etc/apt/sources.list.d/logstash.list
    - key_url: https://artifacts.elastic.co/GPG-KEY-elasticsearch

install logstash:
  pkg.installed:
    - name: logstash
    - version: {{ logstash['version'] }}
    - hold: {{ logstash['hold'] | default(False) }}
    - require:
      - pkgrepo: add logstash repo
      - pkg: openjdk-8-jre

{% if salt['pillar.get']('logstash:config') %}
/etc/logstash/logstash.yml:
  file.serialize:
    - dataset_pillar: logstash:config
    - formatter: yaml
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: install logstash
{% endif %}

{% if salt['pillar.get']('logstash:pipelines') %}
{% for pipeline in salt['pillar.get']('logstash:pipelines') %}
/etc/logstash/conf.d/{{ pipeline }}.conf:
  file.managed:
    - contents_pillar: logstash:pipelines:{{ pipeline }}:data
    - user: root
    - group: logstash
    - mode: 660
    - require:
      - install logstash
{% endfor %}
{% endif %}

logstash:
  service.running:
    - restart: {{ logstash['restart'] | default(True) }}
    - enable: {{ logstash['enable'] | default(True) }}
    - require:
      - pkg: install logstash
    - watch:
      {% if salt['pillar.get']('logstash:config') %}
      - file: /etc/logstash/logstash.yml
      {% endif %}
      {% if salt['pillar.get']('logstash:pipelines') %}
      - file: /etc/logstash/conf.d/*
      {% endif %}
      - pkg: logstash
