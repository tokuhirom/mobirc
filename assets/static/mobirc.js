function ts() { return (new Date()).getTime(); }

var current_channel;

function escapeHTML(str) {
    return str.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function reload_log() {
    if (!current_channel) { return; }

    $.get(docroot + 'ajax/channel', {channel: current_channel}, function (data) {
        $('#contents').html(data);
    });
    $('#msg').focus();
}

function send_message() {
    if (!current_channel) { return; }

    $.post(docroot + 'api/send_cmd', {"channel":current_channel, "msg":($('#msg').get())[0].value}, function (html) {
        setTimeout( function () { reload_log(); }, 1*1000 );

        $('#contents br:last').focus();

        $('#msg').val('');
        $('#msg').focus();
    });
}

// onload
$(function () {
    $('#msg').focus();

    (function () {
        var reload_menu = function () {
            $('#ChannelContainer').load(
                docroot + 'ajax/menu?time=' + ts(),
                ''
            );
        }

        reload_menu();
        setInterval(reload_menu, 4*1000);
    })();

    $('#ChannelContainer .channel a').live('click', function () {
        var channel_name = $(this).text();

        current_channel = channel_name;
        reload_log();

        $.getJSON(docroot + 'api/members', {"channel": channel_name}, function (json) {
            var container = $('#NickContainer');
            container.empty();
            for (var i=0; i<json.length; i++) {
                container.append(
                    $(document.createElement('span')).text(json[i])
                ).append(document.createElement('br'));
            }
        });
        $(this).parent().removeClass('unread');
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
});

