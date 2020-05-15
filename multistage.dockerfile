    
### ================================== ###
###   STAGE 1 CREATE PARENT IMAGE      ###
### ================================== ###

# https://www.docker.com/blog/docker-arm-virtual-meetup-multi-arch-with-buildx/

FROM --platform=$BUILDPLATFORM alpine as builder-base1

RUN echo "builder-base1 $BUILDPLATFORM" > /imageplatform.txt && \
    uname -a >> /imageplatform.txt
   
### ================================== ###
###   STAGE 2 COMPILE NAGIOS SOURCES   ###
### ================================== ###


FROM builder-base1 as builder-base2

RUN echo "builder-base2 $BUILDPLATFORM" > /imageplatform.txt && \
    uname -a >> /imageplatform.txt
   

### ================================== ###
###   STAGE 3 COMPILE NAGIOS SOURCES   ###
### ================================== ###

FROM builder-base2 as builder-compile

MAINTAINER Christos Manios <maniopaido@gmail.com>

LABEL name="Nagios" \
      nagiosVersion="4.4.5" \
      nagiosPluginsVersion="2.2.1" \
      nrpeVersion="3.2.1" \
      homepage="https://www.nagios.com/" \
      maintainer="Christos Manios <maniopaido@gmail.com>" \
      build="1"

RUN echo "builder-compile $BUILDPLATFORM" > /imageplatform.txt && \
    uname -a >> /imageplatform.txt


# docker build --target mybase \
#        --cache-from=manios/nagios:builder-base \
#        -t manios/nagios:builder-base .


# docker build --target sourcebuilder \
#        --cache-from=manios/nagios:builder-base \
#        --cache-from=manios/nagios:builder-compile \
#        -t manios/nagios:builder-compile .



# docker buildx build \
#     --platform "linux/amd64,linux/arm/v6,linux/arm/v7" \
#     --cache-from=type=registry,ref=manios/nagios:builder-base1 \
#     --cache-to=type=registry,ref=manios/nagios:builder-base1,mode=max \
#     --push \
#     --progress plain \
#     -f multistage.dockerfile \
#     -t manios/nagios:platformas .
