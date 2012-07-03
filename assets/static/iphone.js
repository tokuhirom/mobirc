function ts() { return (new Date()).getTime(); }

var load_url;
var load_menu_timer;
var load_url_timer;

function contents_load(url) {
    var joinner = (url.indexOf('?') == -1) ? '?' : '&';
    $.getJSON(
        url + joinner + 'time='+ts(),
        function (res) {
            $('#contents').html( res.messages.join("<br />") );
            $('title').html( res.channel_name + " - mobirc" );
        },
        function (err) {
            alert(err);
        }
    );
    load_url = url;
}

function send_message() {
    $.post(load_url, {"msg":($('#msg').get())[0].value}, function (html) {
        setTimeout( function () { if (load_url) { contents_load(load_url) } }, 1*1000 );

        $('#msg').val('');
    });
}

function load_menu () {
    $('#menu').load(
        docroot + 'iphone/menu?time=' + ts(),
        '',
        function () {
            $('#menu .channel a').click(function () {
                contents_load(docroot + 'iphone/channel?channel=' + encodeURIComponent($(this).text()) + '&server=' + encodeURIComponent($(this).data('server')), $(this).text());
                $(this).parent().removeClass('unread');
                return false;
            });

            var keyword_cb = function () {
                contents_load(docroot + 'iphone/keyword')
                $(this).parent().remove();
            };
            $('#menu .keyword_recent_notice a').click(keyword_cb).keypress(keyword_cb);
        }
    );
}

// onload
$(function () {
    load_menu();
});

function lmt() { load_menu_timer = setInterval(load_menu, 11*1000); };
function lut() { load_url_timer = setInterval(function(){ if(load_url){ contents_load(load_url); } }, 10*1000); };
lmt();
lut();
