FROM debian:jessie
MAINTAINER Paulius Danenas <danpaulius@gmail.com>
ENV DEBIAN_FRONTEND noninteractive
ENV DRUPAL_VERSION 8.3.2

RUN echo $DRUPAL_VERSION | sed "s/^.*\([0-9.]*\).*/\1/"