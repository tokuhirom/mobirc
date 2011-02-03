(function () {
    if (!console) {
        console = {
            log: function () { }
        };
    }

    // Simple JavaScript Templating
    // John Resig - http://ejohn.org/ - MIT Licensed
    var cache = {};
    this.tmpl = function tmpl(str, data){
        // Figure out if we're getting a template, or if we need to
        // load the template - and be sure to cache the result.
        var fn = !/\W/.test(str) ?
        cache[str] = cache[str] ||
            tmpl(document.getElementById(str).innerHTML) :
        
        // Generate a reusable function that will serve as a template
        // generator (and which will be cached).
        new Function("obj",
            "var p=[],print=function(){p.push.apply(p,arguments);};" +
            
            // Introduce the data as local variables using with(){}
            "with(obj){p.push('" +
            
            // Convert the template into pure JavaScript
            str
            .replace(/[\r\t\n]/g, " ")
            .split("<%").join("\t")
            .replace(/((^|%>)[^\t]*)'/g, "$1\r")
            .replace(/\t=(.*?)%>/g, "',$1,'")
            .split("\t").join("');")
            .split("%>").join("p.push('")
            .split("\r").join("\\'")
        + "');}return p.join('');");
        
        // Provide some basic currying to the user
        return data ? fn( data ) : fn;
    };

    function updateChannelList() {
        $.ajax({
            url: docroot + 'api/channels',
            cache: false,
            error: function () { alert("ERROR"); },
            success: function (x) {
                var container = $('#ChannelList');
                container.find('li.channel').remove();
                for (var i=0; i<x.length; i++) {
                    (function () {
                        var name = x[i].name;
                        var a = $('<a />').text(x[i].name).click(function () {
                            $.mobile.changePage({
                                url: '#channel',
                                data: encodeURIComponent(name),
                                type: "get"
                            }, 'slide', false, true);
                            return false;
                        });
                        var span = $('<span class="ui-li-count" />').text(x[i].unread_lines);
                        container.append(
                            $('<li class="channel" />').append(a).append(span)
                        );
                    })();
                }
                container.listview('refresh');
            }
        });
    };
    $(function () {
        $.mobile.ajaxFormsEnabled = false;
        $('#RefreshChannelListButton').bind('click tap', function () {
            updateChannelList();
        });
        $('#ClearAllUnread').bind('click tap', function() {
            $.post(
                docroot + 'api/clear_all_unread',
                '',
                function () {
                    updateChannelList();
                }
            );
        });

        $('#ChannelForm').live('submit', function (e) {
            e.stopPropagation();
            var elem = $(this);
            if (elem.find('input[type="text"]').val().length==0) {
                return false;
            }
            $.mobile.pageLoading(false);
            $.ajax({
                type: 'post',
                cache: false,
                data: $(this).serialize(),
                url: docroot + 'api/send_msg',
                success: function () {
                    $.mobile.pageLoading(true);
                    elem.find('input[type="text"]').val('');
                    update_channel_log(elem.find('input[type="hidden"]').val());
                    return false;
                },
                error: function () {
                    alert("fail");
                },
            });
            return false;
        });

        function update_channel_log(channel_name) {
            $.ajax({
                url: docroot + 'api/channel_log',
                data: { channel: channel_name },
                cache: false,
                type: 'post',
                success: function (data) {
                    data = data.reverse();
                    var show_log = tmpl("tmpl_channel_log"), html = "";
                    for ( var i = 0; i < data.length; i++ ) {
                        html += show_log( data[i] );
                    }
                    $('#channel #channel_log').html(html);
                },
                error : function (e) { alert("error: " + e) }
            });
        }

        var change = function () {
            var x = location.hash.split(/\?/)
            if (x[0] == '#channel') {
                var channel_name = decodeURIComponent(x[1]);
                if (channel_name.length > 0) {
                    $('#channel h1').text(channel_name)
                    $('#channel input[type="hidden"]').val(channel_name);
                    update_channel_log(channel_name);
                } else {
                    updateChannelList();
                }
            } else {
                updateChannelList();
            }
        };
        $('div').live('pageshow',function(event, ui){
            change();
            return true;
        });
        change();
    });
})();
