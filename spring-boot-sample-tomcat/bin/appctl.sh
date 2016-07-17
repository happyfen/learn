#!/bin/bash

PROG_NAME=$0


usage() {
    echo "Usage: $PROG_NAME {start|stop|restart}"
    exit 1;
}

if [ "$UID" -eq 0 ]; then
    echo "can't run as root"
    exit 1
fi

if [ $# -lt 1 ]; then
    usage
fi

APP_HOME=""
if [ -z "${APP_HOME}" ]; then
	## resolve links - $0 may be a link to maven's home
	PRG="$0"

	# need this for relative symlinks
	while [ -h "$PRG" ] ; do
		ls=`ls -ld "$PRG"`
		link=`expr "$ls" : '.*-> \(.*\)$'`
		if expr "$link" : '/.*' > /dev/null; then
			PRG="$link"
		else
			PRG="`dirname "$PRG"`/$link"
		fi
	done

	APP_HOME=$(cd $(dirname "$PRG")/.. && pwd)
fi

export CLASSPATH=${APP_HOME}/conf
for e in $(ls "${APP_HOME}"/lib/*.jar); do
	CLASSPATH="${CLASSPATH}:${e}"
done
#echo "CLASSPATH=${CLASSPATH}"

test -z "$JPDA_ENABLE" && JPDA_ENABLE=0
if [ "$JPDA_ENABLE" -eq 1 ]; then
	if [ -z "$JPDA_TRANSPORT" ]; then
		JPDA_TRANSPORT="dt_socket"
	fi
	if [ -z "$JPDA_ADDRESS" ]; then
		JPDA_ADDRESS="8000"
	fi
	if [ -z "$JPDA_SUSPEND" ]; then
		JPDA_SUSPEND="n"
	fi
	if [ -z "$JPDA_OPTS" ]; then
		JPDA_OPTS="-agentlib:jdwp=transport=$JPDA_TRANSPORT,address=$JPDA_ADDRESS,server=y,suspend=$JPDA_SUSPEND"
	fi
fi
	
start_args=(
-Xmn512m -Xms1g -Xmx1g -XX:MaxMetaspaceSize=125m  -XX:MetaspaceSize=125m
## -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:gc.log
-XX:+UseConcMarkSweepGC $JPDA_OPTS
sample.tomcat.SampleTomcatApplication
)

die() {
    if [ "$#" -gt 0 ]; then
        echo "ERROR:" "$@"
    fi
    exit 128
}

extract_tgz() {
    local tgz_path="$1"
    local dir_path="$2"

    echo "extract ${tgz_path}"
    cd "$(dirname "${dir_path}")" || exit
    rm -rf "${dir_path}" || exit
    tar xzf "${tgz_path}" || exit
    test -d "${dir_path}" || die "no directory: ${dir_path}"
    touch --reference "${tgz_path}" "${tgz_path}.timestamp" || exit
}

: '
    # dir exists
        # tgz exists
            # tgz changed - extract_tgz
            # tgz not changed - return SUCCESS
        # tgz not exists - return SUCCESS
    # dir not exists
        # tgz exists - extract_tgz
        # tgz not exists - return FAIL
'
update_target() {
    local tgz_path="$1"
    local dir_path="$2"

    local error=0
    # dir exists
    if [ -d "${dir_path}" ]; then
        # tgz exists
        if [ -f "${tgz_path}" ]; then
            local need_tar=0
            if [ ! -e "${tgz_path}.timestamp" ]; then
                need_tar=1
            else
                local tgz_time=$(stat -L -c "%Y" "${tgz_path}")
                local last_time=$(stat -L -c "%Y" "${tgz_path}.timestamp")
                if [ $tgz_time -ne $last_time ]; then
                    need_tar=1
                fi
            fi
            # tgz is changed - extract_tgz
            if [ "${need_tar}" -eq 1 ]; then
                extract_tgz "${tgz_path}" "${dir_path}"
            fi
            # tgz not changed - return SUCCESS
        fi
        # tgz not exists - return SUCCESS
    # dir not exists
    else
        # tgz exists - extract_tgz
        if [ -f "${tgz_path}" ]; then
            extract_tgz "${tgz_path}" "${dir_path}"
        # tgz not exists - return FAIL
        else
            echo "ERROR: ${tgz_path} NOT EXISTS"
            error=1
        fi
    fi

    return $error
}

get_pid() {
	    ps -ef | grep 'com.taobao.csp.amazon.agent.AgentMai[n]' |grep "$AGENT_TYPE"| awk '{print $2}'
}

start() {
	pid=$(get_pid)
	if [ -n "$pid" ]; then
		ps -p "$pid" -fww
		die "Agent already running! Start aborted."
	fi

	#update_target "${APP_TGZ}" "${APP_HOME}" || exit
	echo "start agent..."
	nohup /home/hanyin.hy/taobao-jdk/opt/taobao/install/ajdk-8_1_1-b18/bin/java -Xbootclasspath/p:/home/hanyin.hy/jdk8nextbytes.jar -Djava.security.egd=file:/dev/./urandom "${start_args[@]}" >stdout.log 2>stderr.log &
	ps -p "$!" -fww
}

stop() {
	pid=$(get_pid)
	for pid in $pid; do
		kill -9 $pid
	done
}

case "$ACTION" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    restart)
        stop
        sleep 3
        start
    ;;
    ps)
    	pid=$(get_pid)
    	if [ -n "$pid" ]; then
			shift
			argv=( "${@}" )
			test "${#argv}" -eq 0 && argv=( -fww )
			ps -p "$(get_pid)" "${argv[@]}"
		else
			exit
		fi
    ;;
    java)
    	#test -z "$(get_pid)" && { update_target "${APP_TGZ}" "${APP_HOME}" || exit ; }
    	shift
    	java $JPDA_OPTS "${@}"
    ;;
    *)
		#test -z "$(get_pid)" && { update_target "${APP_TGZ}" "${APP_HOME}" || exit ; }
		"${@}"
    ;;
esac
