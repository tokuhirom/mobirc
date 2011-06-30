(function () {
    function ts() { return (new Date()).getTime(); }
    Mobirc = {
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
            var url = docroot + 'api/channels?t=' + ts();
            $.ajax({
                url: url,
            }).error(function () {
                alert("AJAX error");
            }).success(function (dat) {
                console.log(dat);
                $('#ChannelList').empty();
                $('#ChannelListTmpl').tmpl({channels:dat}).appendTo('#ChannelList');

                Mobirc.bind('#menu .channel a', function () {
                    var elem = $(this);
                    elem.addClass('active');
                    Mobirc.loadContent(elem.text());
                    return false;
                });

                Mobirc.hideLoading();
            });
        },
        loadContent: function (channel) {
            Mobirc.showLoading();
            $('#contents').load(
                docroot + 'iphone2/channel?channel=' + encodeURIComponent(channel) + '&t=' + ts(),
                '',
                function() {
                    Mobirc.showPage('#contents');

                    $('#input').ajaxForm(function () {
                        Mobirc.loadContent(channel);
                    });
                    Mobirc.bind('#goMenuButton', function() {
                        Mobirc.showPage('#menu');

                        Mobirc.updateChannelList();
                        return false;
                    });
                    Mobirc.bind('#showChannelList', function() {
                        Mobirc.showPage('#menu');

                        Mobirc.updateChannelList();
                        return false;
                    });

                    Mobirc.hideLoading();
                }
            );
        },
        showPage: function (id) { // id includes header '#'
            $('body > div').hide();
            $(id).show();

            Mobirc.dispatch(id);
        },
        initialize: function () {
            Mobirc.bind('#RefreshMenu', function() {
                Mobirc.updateChannelList();
            });
            Mobirc.bind('#ClearAllUnread', function() {
                $.post(
                    '/iphone2/clear_all_unread',
                    '',
                    function () {
                        Mobirc.updateChannelList();
                    }
                );
            });

            var page = '#menu';
            if (location.hash.match(/^#[a-z0-9_-]+$/)) {
                page = location.hash;
            }
            Mobirc.showPage(page);

            $('a').live('click', function () {
                var href = $(this).attr('href');
                Mobirc.showPage(href);
                location.href=href;
                return false;
            });
        },
        dispatch: function (id) {
            var code = Mobirc.dispatchMap[id.replace(/^#/, '')];
            if (code) {
                code();
            }
        },
        dispatchMap: {
            menu: function () {
                Mobirc.updateChannelList();
            }
        }
    };
    $(function () {
        Mobirc.initialize();
    });
})();
