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
                    container.append(self.format_html(data[i]));
                }
                $('#ChannelLog').scrollTop(10000000);
            });
            $('#msg').focus();
        },
        format_html: function (log, display_channel_name) {
            var keta = function (x) { x = ''+x; return x.length == 1 ? '0'+x : x; };

            var html = '<div class="log"><span class="time"><span class="hour">' + keta(log.hour) + '</span><span class="colon">:</span><span class="minute">' + keta(log.minute) + '</span></span>';
            if (display_channel_name) {
                html += '<span class="channel">' + log.channel_name + '</span>';
            }
            if (log.who) {
                html += '<span class="' + log.who_class + '">(' + log.who + ')</span>';
            }
            html += '<span class="message ' + log['class'] + '">' + log.html_body + "</span></div>";
            return html;
        },
        add_message: function (log) {
            var self = this;

            if (self.current_channel == log.channel_name) {
                // insert to channel-log pain
                (function () {
                    var container = $('#ChannelLog');
                    self.truncate_log_pain(container, 100);
                    container.append(self.format_html(log));
                    $('#ChannelLog').scrollTop(10000000);
                })();
            } else {
                // insert to combined-log pain
                (function() {
                    var container = $('#CombinedLog');
                    self.truncate_log_pain(container, 30);
                    container.append(self.format_html(log, true));
                    $('#CombinedLog').scrollTop(10000000);

                    if (log.channel_name == '*keyword*') { return; }
                    var unread_fg = log['class'] != 'join' && log['class'] != 'part';
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
                            .append(
                                $(document.createElement('a'))
                                    .attr('href', '#')
                                    .text(name)
                            );
                if (name == Mobirc.current_channel) {
                    div.addClass('current');
                }
                Mobirc.channels[name] = div;
                $('#ChannelContainer').append(div);
            }
            if (name != Mobirc.current_channel && is_unread) {
                Mobirc.channels[name].addClass('unread');
            }
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
        $('#ChannelContainer .channel a').live('click', function () {
            var channel_name = $(this).text();

            $('#ChannelContainer .current').removeClass('current');
            $(this).parent().addClass('current');
            $(this).parent().removeClass('unread').removeClass('keyword');

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
        $.ev.loop('/tatsumaki/poll?client_id=' + Math.random(), {
            message: function (x) {
                Mobirc.add_message(x);
            }
        });
    });

})();
