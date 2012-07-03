/*
 * TODO:
 * resizable view
 */

(function () {
    // fucking IE.
    $.ajaxSetup({cache: false});

    // utility functions
    function ts() { return (new Date()).getTime(); }
    function escapeHTML(str) {
        return str.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/'/, '&#39;');
    }

    var Mobirc = {
        current_channel: '*server*',
        current_server: window.mobircDefaultServer,
        channels: {},
        load_log: function () {
            var self = this;
            $.getJSON(docroot + 'api/channel_log', {channel: Mobirc.current_channel, server: Mobirc.current_server}, function (data) {
                var container = $('#ChannelLog');
                container.empty();
                for (var i=0; i<data.length; i++) {
                    container.append('<div class="log">' + self.format_html(data[i]) + '</div>');
                }
                $('#ChannelLog').scrollTop(10000000);
            });
            $('#msg').focus();
        },
        format_html: function (log, display_channel_name) {
            var keta = function (x) { x = ''+x; return x.length == 1 ? '0'+x : x; };

            var html = '<span class="time"><span class="hour">' + keta(log.hour) + '</span><span class="colon">:</span><span class="minute">' + keta(log.minute) + '</span></span> ';
            if (display_channel_name) {
                html += '<span class="channel">' + log.channel_fullname + '</span> ';
            }
            if (log.who) {
                html += '<span class="' + log.who_class + '">(' + log.who + ')</span> ';
            }
            html += '<span class="message ' + log['class'] + '">' + log.html_body + "</span>";
            return html;
        },
        add_message: function (log, unread_fg) {
            var self = this;

            if (self.current_channel == log.channel_name && self.current_server == log.server) {
                // insert to channel-log pain
                (function () {
                    var container = $('#ChannelLog');
                    self.truncate_log_pain(container, 100);
                    container.append('<div class="log" data-server="' + log.server + '">' + self.format_html(log) + '</div>');
                    $('#ChannelLog').scrollTop(10000000);
                })();
            } else {
                // insert to combined-log pain
                (function() {
                    var container = $('#CombinedLog');
                    self.truncate_log_pain(container, 30);
                    var channel_name = log.channel_name;
                    var div = $(document.createElement('div')).addClass('log').data('server', log.server).append(self.format_html(log, true)).dblclick(function () {
                        Mobirc.show_channel(channel_name, log.channel_fullname, log.server);
                    });

                    container.append(div);
                    $('#CombinedLog').scrollTop(10000000);

                    if (log.channel_name == '*keyword*') { return; }
                    if (log['class'] == 'join' || log['class'] == 'part') {
                        unread_fg = false;
                    }
                    Mobirc.update_channel_elem(log.channel_name, log.channel_fullname, log.server, unread_fg);
                    if (log.is_keyword == 1) {
                        Mobirc.channels[log.channel_name].addClass('keyword');
                    }
                })();
            }
        },
        truncate_log_pain: function (container, limit) {
            if ($('.log', container).length > limit) {
                $(':first', container).remove();
            }
        },
        update_channel_elem: function (name, fullname, server, is_unread) {
            if (!Mobirc.channels[fullname]) {
                var div = $(document.createElement('div'))
                            .addClass('channel')
                            .text(fullname)
                            .data('server', server)
                            .data('channel', name);
                if (name == Mobirc.current_channel && server === Mobirc.current_server) {
                    div.addClass('current');
                }
                Mobirc.channels[fullname] = div;
                $('#ChannelContainer').append(div);
            }
            if (name != Mobirc.current_channel && server === Mobirc.current_server && is_unread) {
                Mobirc.channels[fullname].addClass('unread');
            }
        },
        show_channel: function (name, fullname, server) {
            var div = Mobirc.channels[fullname];
            if (div) { div.click(); }
        }
    };

    (function () {
        var ua = navigator.userAgent.toLowerCase();
        if (ua.indexOf('msie') != -1) {
            Mobirc.is_ie = true;
        }
    })();

    // onload
    $(function () {
        $('#msg').focus();

        Mobirc.load_log();

        $('#CommandForm').submit(function () {
            $.post(docroot + 'api/send_msg', {"channel":Mobirc.current_channel, "server": Mobirc.current_server, "msg":($('#msg').get())[0].value}, function (html) {
                $('#msg').val('');
                $('#msg').focus();
            });
        });

        // build ChannelContainer
        $.getJSON(docroot + 'api/channels', {"time":ts()}, function (json) {
            for (var i=0; i<json.length; i++) {
                var row = json[i];
                Mobirc.update_channel_elem(row.name, row.fullname, row.server, row.unread_lines > 0);
            }
        });

        // add live event
        $('#ChannelContainer .channel').live('click', function () {
            var channel_name = $(this).data('channel');
            var server = $(this).data('server');

            $('#ChannelContainer .current').removeClass('current');
            $(this).addClass('current');
            $(this).removeClass('unread').removeClass('keyword');

            Mobirc.current_channel = channel_name;
            Mobirc.current_server = server;
            Mobirc.load_log();

            // reload nicks
            $.getJSON(docroot + 'api/members', {"channel": channel_name, "server": server}, function (json) {
                var container = $('#NickContainer');
                container.empty();
                for (var i=0; i<json.length; i++) {
                    container.append(
                        $(document.createElement('span')).text(json[i])
                    ).append(document.createElement('br'));
                }
            });

            return false;
        });


        // adjust widget size
        (function () {
            var adjust_channel_log_pane = function () {
                $('#ChannelLog').height($('#ChannelPane').height() - $('#CommandForm').height() - 10);
            };
            var adjust_page_body_height = function () {
                $('#PageBody').height($(document).height() - $('#nav').height() - 2);
            };
            adjust_page_body_height();
            var pbLayout = $('#PageBody').layout({
                applyDefaultStyles: true
                , closable: false
            })
            var mLayout = $('#Main').layout({
                closable: false
                , south__size: $('#PageBody').height() * 0.2
                , onresize: function () {
                    adjust_channel_log_pane();
                }
            });
            adjust_channel_log_pane();
            var sLayout = $('#Side').layout({
                closable: false
                , south__size: $('#PageBody').height() * 0.4
            });
            if (Mobirc.is_ie) { // bad knowhow
                setTimeout(adjust_page_body_height, 100);
            }
            $(window).resize(function () {
                adjust_page_body_height();
                setInterval(function () { pbLayout.resizeAll() }, 300);
                setInterval(function () { sLayout.resizeAll() }, 300);
                setInterval(function () { mLayout.resizeAll() }, 300);
            });
        })();

        $('#nav').droppy();

        $('#MenuBtnAbout').click(function () {
            $('#DialogAbout').dialog({
                bgiframe: true,
                autoOpen: true,
                modal: true,
                buttons: {
                    "OK" : function () { $(this).dialog('close') }
                }
            });
            return false;
        });
        $('#MenuBtnChannelShowTopic').click(function () {
            $.getJSON(docroot + 'api/channel_topic', {
                channel: Mobirc.current_channel,
                server: Mobirc.current_server
            }, function (x) {
                var container = $('#ChannelLog');
                container.append('<div class="log">' + escapeHTML(x.topic) + '</div>');
            });
        });
        $('#MenuBtnClearAllUnread').click(function () {
            $.post(docroot + 'api/clear_all_unread', function () {
                $('.unread').removeClass('unread');
                alert('Cleared');
            });
            return false;
        });

        // polling
        (function () {
            var first_time = true;
            $.ev.loop('/tatsumaki/poll?client_id=' + Math.random(), function (messages) {
                for (var i = 0; i < messages.length; i++) {
                    var m = messages[i];
                    if (!m) continue;
                    var unread_fg = !first_time;
                    Mobirc.add_message(m, unread_fg);
                }
                first_time = false;
            });
        })();
        
    });
})();
