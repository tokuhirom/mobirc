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
        channels: {},
        load_log: function () {
            var self = this;
            $.getJSON(docroot + 'api/channel_log', {channel: Mobirc.current_channel}, function (data) {
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

            var html = '<span class="time"><span class="hour">' + keta(log.hour) + '</span><span class="colon">:</span><span class="minute">' + keta(log.minute) + '</span></span>';
            if (display_channel_name) {
                html += '<span class="channel">' + log.channel_name + '</span>';
            }
            if (log.who) {
                html += '<span class="' + log.who_class + '">(' + log.who + ')</span>';
            }
            html += '<span class="message ' + log['class'] + '">' + log.html_body + "</span>";
            return html;
        },
        add_message: function (log, unread_fg) {
            var self = this;

            if (self.current_channel == log.channel_name) {
                // insert to channel-log pain
                (function () {
                    var container = $('#ChannelLog');
                    self.truncate_log_pain(container, 100);
                    container.append('<div class="log">' + self.format_html(log) + '</div>');
                    $('#ChannelLog').scrollTop(10000000);
                })();
            } else {
                // insert to combined-log pain
                (function() {
                    var container = $('#CombinedLog');
                    self.truncate_log_pain(container, 30);
                    var channel_name = log.channel_name;
                    var div = $(document.createElement('div')).addClass('log').append(self.format_html(log, true)).dblclick(function () {
                        Mobirc.show_channel(channel_name);
                    });

                    container.append(div);
                    $('#CombinedLog').scrollTop(10000000);

                    if (log.channel_name == '*keyword*') { return; }
                    if (log['class'] == 'join' || log['class'] == 'part') {
                        unread_fg = false;
                    }
                    Mobirc.update_channel_elem(log.channel_name, unread_fg);
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
        update_channel_elem: function (name, is_unread) {
            if (!Mobirc.channels[name]) {
                var div = $(document.createElement('div'))
                            .addClass('channel')
                            .text(name);
                if (name == Mobirc.current_channel) {
                    div.addClass('current');
                }
                Mobirc.channels[name] = div;
                $('#ChannelContainer').append(div);
            }
            if (name != Mobirc.current_channel && is_unread) {
                Mobirc.channels[name].addClass('unread');
            }
        },
        show_channel: function (name) {
            var div = Mobirc.channels[name];
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
            $.post(docroot + 'api/send_msg', {"channel":Mobirc.current_channel, "msg":($('#msg').get())[0].value}, function (html) {
                $('#msg').val('');
                $('#msg').focus();
            });
        });

        // build ChannelContainer
        $.getJSON(docroot + 'api/channels', {"time":ts()}, function (json) {
            for (var i=0; i<json.length; i++) {
                var row = json[i];
                Mobirc.update_channel_elem(row.name, row.unread_lines > 0);
            }
        });

        // add live event
        $('#ChannelContainer .channel').live('click', function () {
            var channel_name = $(this).text();

            $('#ChannelContainer .current').removeClass('current');
            $(this).addClass('current');
            $(this).removeClass('unread').removeClass('keyword');

            Mobirc.current_channel = channel_name;
            Mobirc.load_log();

            // reload nicks
            $.getJSON(docroot + 'api/members', {"channel": channel_name}, function (json) {
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

        // $('#menu').resizable();

        // adjust widget size
        (function () {
            var rebuild_window = function () {
                var win = $(window);
                var footer = $('#Footer');

                $('#Main').width($('#PageBody').width()*0.79);
                $('#Side').width($('#PageBody').width()*0.20);

                $('#PageBody').height($(document).height() - footer.height() - 3);
                $('#ChannelLog').height(($('#PageBody').height() - $('#CommandForm').height() - 10) * 0.7);
                $('#CombinedLog').height(($('#PageBody').height() - $('#CommandForm').height() - 10) * 0.3);
                $('#Side').height($('#PageBody').height() - footer.height()-10);
                $('#Side #NickContainer').height($('#Side').height() * 0.30);
                $('#Side #ChannelContainer').height($('#Side').height() * 0.70);
            };
            rebuild_window();
            if (Mobirc.is_ie) { // bad knowhow
                setTimeout(rebuild_window, 100);
            }
            $(window).resize(rebuild_window);
        })();

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
