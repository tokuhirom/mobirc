(function () {

if (!window.console) {
    window.console = {
        log: function () { }
    };
}

// initialize jQuery mobile
$(document).bind("mobileinit", function(){
    // I want to handle location.hash fully.
    $.mobile.hashListeningEnabled = true;
    $.mobile.ajaxFormsEnabled =  false; // DEPRECATED
});

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

/* controllers */

window.Mobirc = window.Mobirc || {};
window.Mobirc.ChannelViewController = ChannelViewController = {};
ChannelViewController.setup = function (channel_name) {
    this.init();
    this.channel_name = channel_name;

    $('#channel h1').text(channel_name);
    $('#channel input[type="hidden"]').val(channel_name);
    this.fetch_log(channel_name);
};
ChannelViewController.init = function () {
    if (this.initialized) { return; }
    this.initialized = true;

    var self = this;

    $('#ChannelForm').submit(function (e) {
        e.stopPropagation();
        console.log("channelForm");

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
        }).success(function () {
            $.mobile.pageLoading(true);
            elem.find('input[type="text"]').val('');
            Mobirc.ChannelViewController.fetch_log(self.channel_name);
            return false;
        }).error(function () {
            alert("fail");
        });
        return false;
    });
};
ChannelViewController.fetch_log = function (channel_name) {
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
};

var ChannelListViewController = window.Mobirc.ChannelListViewController = {};
ChannelListViewController.setup = function () {
    this.init();

    $.ajax({
        url: docroot + 'api/channels',
        cache: false,
    }).success(function (x) {
        console.log("loaded channels");
        var container = $('ul#ChannelList');
        var removed_elements = container.find('li.channel').remove(); // remove last channe list
        var i=0,
            max=x.length;
        setTimeout(
            function () {
                push_elem(i);
                ++i;
                if (i==max) {
                    container.listview('refresh');
                } else {
                    setTimeout(arguments.callee, 1);
                }
            }, 0
        );
        function push_elem(i) {
            var a = $('<a />').text(x[i].name).attr('href', '#channel?' + encodeURIComponent(x[i].name));
            var span = $('<span class="ui-li-count" />').text(x[i].unread_lines);
            container.append(
                $('<li class="channel" />').append(a).append(span)
            );
        }
    }).error(function () {
        alert("ERROR");
    });
};
ChannelListViewController.init = function (channel_name) {
    if (this.initialized) { return; }
    this.initialized = true;

    var self = this;
    $('#RefreshChannelListButton').bind('click tap', function () {
        self.setup();
    });
    $('#ClearAllUnread').bind('click tap', function() {
        console.log("clear");
        $.post(
            docroot + 'api/clear_all_unread',
            ''
        ).success(function () {
            self.setup();
        });
    });
};

$(function () {
    $('#channel').bind('pagebeforeshow', function () {
        var ret = location.hash.match(/^#channel\?(.+)$/);
        console.log("showing channel page : " + ret[1]);
        ChannelViewController.setup(decodeURIComponent(ret[1]));
    });
    $('#index').bind('pageshow', function () {
        console.log("index page");
        ChannelListViewController.setup();
        return false;
    });
});

$(window).bind('hashchange', function (e) {
    console.log("HASHCHANGE");
    var ret = location.hash.match(/^#channel\?(.+)$/)
    if (ret) {
        $.mobile.urlHistory.ignoreNextHashChange = true;
        var channel_name = ret[1];
        $.mobile.changePage($('#channel'));
        $.mobile.hashListeningEnabled = false;
    }
});

})();
