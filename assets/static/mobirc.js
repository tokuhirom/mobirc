(function () {

    function ts() { return (new Date()).getTime(); }

    var current_channel;

    function escapeHTML(str) {
        return str.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/'/, '&#39;');
    }

    function reload_log() {
        if (!current_channel) { return; }

        $.get(docroot + 'ajax/log', {channel: current_channel}, function (data) {
            $('#Log').html(data);
            $('#Log').scrollTop(10000000);
        });
        $('#msg').focus();
    }

    function send_message() {
        if (!current_channel) { return; }

        $.post(docroot + 'api/send_msg', {"channel":current_channel, "msg":($('#msg').get())[0].value}, function (html) {
            setTimeout( function () { reload_log(); }, 1*1000 );

            $('#msg').val('');
            $('#msg').focus();
        });
    }

    // onload
    $(function () {
        $('#msg').focus();

        current_channel = '*server*';
        reload_log();

        // rebuild ChannelContaier
        (function () {
            var reload_menu = function () {
                $.getJSON(docroot + 'api/channels', {"time":ts()}, function (json) {
                    var container = $('#ChannelContainer');
                    container.empty();
                    for (var i=0; i<json.length; i++) {
                        var row = json[i];
                        var div = $(document.createElement('div'))
                                    .addClass('channel')
                                    .append(
                                        $(document.createElement('a'))
                                            .attr('href', '#')
                                            .text(row.name)
                                    );
                        if (row.name == current_channel) {
                            div.addClass('current');
                        } else if (row.unread_lines > 0) {
                            div.addClass('unread');
                        }
                        container.append(div);
                    }
                });
            }

            reload_menu();
            setInterval(reload_menu, 4*1000);
        })();

        $('#ChannelContainer .channel a').live('click', function () {
            var channel_name = $(this).text();

            $('#ChannelContainer .current').removeClass('current');
            $(this).parent().addClass('current');
            $(this).parent().removeClass('unread');

            current_channel = channel_name;
            reload_log();

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

        // reload log periodically
        setInterval(function(){ reload_log(); }, 5*1000);

        // check keyword
        setInterval(function(){
            $.getJSON(docroot + 'api/keyword', {}, function (json) {
                for (var i=0; i<json.length; i++) {
                    (function () {
                        var row = json[i];
                        var msg = escapeHTML("" + row.channel.name + " <" + row.who + "> " + row.body);
                        var h = "<a onclick='" + row.channel.name
                        $.jGrowl(msg, { sticky: true });
                    })();
                }
            });
        }, 5*1000);

        // adjust widget size
        (function () {
            var rebuild_window = function () {
                var win = $(window);
                var footer = $('#Footer');

                $('#Main').width($('#PageBody').width()*0.79);
                $('#Side').width($('#PageBody').width()*0.20);

                $('#PageBody').height($(document).height() - footer.height() - 3);
                $('#Log').height($('#PageBody').height() - $('#CommandForm').height() - 10);
                $('#Side').height($('#PageBody').height() - footer.height());
                $('#Side #NickContainer').height($('#Side').height() * 0.30);
                $('#Side #ChannelContainer').height($('#Side').height() * 0.70);
            };
            rebuild_window();
            $(window).resize(rebuild_window);
        })();
    });

})();
