echo::header "Application Tests for $NAME ..."


echo::test "freeswitch is ready"
docker exec $NAME bash -l -c "fs_cli -x 'show status' | grep -q 'is ready'"
if (($? == 0)); then
    echo::success "ok"
else
    echo::fail "not ok"
    exit 1
fi

echo::test "freeswitch reloadxml works"
docker exec $NAME bash -l -c "fs_cli -x 'reloadxml' | head -1 | grep -q Success"
if (($? == 0)); then
    echo::success "ok"
else
    echo::fail "not ok"
    exit 1
fi

echo::test "mod_kazoo is listening as correct erlang node and host"
docker exec $NAME bash -l -c "fs_cli -x 'erlang status' | grep -q 'Registered as Erlang node freeswitch@freeswitch.local, visible as freeswitch'"
if (($? == 0)); then
    echo::success "ok"
else
    echo::fail "not ok"
    exit 1
fi

echo::test "mod_kazoo is bound to correct ip and port"
docker exec $NAME bash -l -c "fs_cli -x 'erlang status' | grep -q '0.0.0.0:8031'"
if (($? == 0)); then
    echo::success "ok"
else
    echo::fail "not ok"
    exit 1
fi

echo::test "mod_kazoo has the correct cookie"
docker exec $NAME bash -l -c "fs_cli -x 'erlang status' | grep -q 'cookie test-cookie'"
if (($? == 0)); then
    echo::success "ok"
else
    echo::fail "not ok"
    exit 1
fi

for mod in dptools spandsp kazoo event_socket http_cache opus shout h26x g729 silk dialplan_xml say_en; do
    echo::test "kazoo module loaded: $mod"
    docker exec $NAME bash -l -c "fs_cli -x 'show modules' | grep -q mod_${mod}"
    if (($? == 0)); then
        echo::success "ok"
    else
        echo::fail "not ok"
        exit 1
    fi
done

echo >&2
