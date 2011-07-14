// http://d.hatena.ne.jp/amachang/20100917/1284700700
function assert(condition, opt_message) {
    if (!condition) {

        if (window.console) {

            console.log('Assertion Failure');
            if (opt_message) console.log('Message: ' + opt_message);

            if (console.trace) console.trace();
            if (Error().stack) console.log(Error().stack);
        }

        debugger;
    }
}

(function () {
    $.ajaxSetup({cache: false});

    Mobirc = {
        latestPost: '',
        showLoading: function () {
            $('#loading').show();
        },
        hideLoading: function () {
            $('#loading').hide();
        },
        bind: function (selector, callback) {
            $(selector).bind("click", callback);
            $(selector).bind("tap",   callback);
        },
        updateChannelList: function () {
            $('#contents').hide();

            Mobirc.showLoading();
            var url = docroot + 'api/channels';
            $.ajax({
                url: url,
            }).error(function () {
                alert("AJAX error");
            }).success(function (dat) {
                console.log(dat);
                dat.sort(function (a, b) {
                    if (a.unread_lines < b.unread_lines)
                        return -1;
                    if (a.unread_lines > b.unread_lines)
                        return -1;
                    return 0;
                });
                $('#ChannelList').empty();
                $('#ChannelListTmpl').tmpl({channels:dat}).appendTo('#ChannelList');

                Mobirc.bind('#menu .channel a', function () {
                    var elem = $(this);
                    elem.addClass('active');
                    Mobirc.showPage('#channel/' + encodeURIComponent(elem.text()));
                    return false;
                });

                Mobirc.hideLoading();
            });
        },
        loadContent: function (channel) {
            Mobirc.showLoading();
            $('#contents').html('Now loading ' + $(document.createElement('span')).text(channel).html());
            $('#contents').load(
                docroot + 'iphone2/channel?channel=' + encodeURIComponent(channel),
                '',
                function() {
                    $('#input').bind('submit', function() {
                        var msgbox = $('#MessageBox');
                        var msg = msgbox.val();
                        var posthash = channel + "\0" + msg;
                        if (Mobirc.latestPost != posthash) {
                            $.ajax({
                                type: 'POST',
                                url: docroot + 'api/send_msg',
                                data: {
                                    channel: channel,
                                    msg:     msg
                                }
                            }).success(function () {
                                Mobirc.loadContent(channel); // reload
                            });

                            Mobirc.latestPost = posthash;
                        }
                        msgbox.val('');
                        return false; // <-- important!
                    });

                    Mobirc.hideLoading();
                }
            );
        },
        showPage: function (id) { // id includes header '#'
            // dispatch code
            if (id == '#menu') {
                $('body > div').hide();
                Mobirc.updateChannelList();
                $(id).show();
            } else if (id == '#about') {
                $('body > div').hide();
                $('#about').show();
            } else if (id.match(/^#channel\/(.+)$/)) {
                var channel = id.match(/^#channel\/(.+)$/)[1];
                $('body > div').hide();
                $('#contents').show();
                Mobirc.loadContent(decodeURIComponent(channel));
            } else {
                console.debug('Unknown page id: ' + id);
            }
            location.hash=id;
        },
        initialize: function () {
            Mobirc.bind('#RefreshMenu', function() {
                Mobirc.updateChannelList();
            });
            Mobirc.bind('#ClearAllUnread', function() {
                $.post(
                    docroot + 'api/clear_all_unread',
                    '',
                    function () {
                        Mobirc.updateChannelList();
                    }
                );
            });

            var page = '#menu';
            if (location.hash.match(/^#.+$/)) {
                page = location.hash;
            }
            Mobirc.showPage(page);

            $('a').live('click', function () {
                var href = $(this).attr('href');
                Mobirc.showPage(href);
                location.href=href;
                return false;
            });
        }
    };
    $(function () {
        Mobirc.initialize();
    });
})();
