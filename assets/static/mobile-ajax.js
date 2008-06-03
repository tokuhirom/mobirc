window.onerror = function (e) { alert(e); }
var SubmitUtil = {
    containerId: 'submit-iframe-container'

    , hasXHR : false
    , setUp : function () {
        //this.hasXHR = window.XMLHttpRequest == undefined;
        this.hasXHR = false;
        if (!this.hasXHR) {
            this.submitIframe = Mobirc.createFormIframe(this.containerId);
            this.submitIframe.style.width = "0px";
            this.submitIframe.style.height = "0px";
        }
    }
    , initialize : function () {
        if (!this.hasXHR) {
            try { this.submitIframe.contentWindow.document.charset = "Shift_JIS"; } catch (e) {}
            this.submitIframe.contentWindow.document.writeln("<body></body>");
        }
    }
    , submit : function (channelEsc, msg) {
        if (this.hasXHR) 
            this.submitInternalXHR(channelEsc, msg);
        else 
            this.submitInternalIframe(channelEsc, msg);
    }
    , submitInternalXHR : function (channelEsc, msg) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", path, true);
        xhr.onreadystatechange = function () {
            if (xhr.readyState == 4 && xhr.status >= 200 && xhr.status < 400) {
                eval(xhr.responseText);
            }
        }
        xhr.send("msg="+encodeURIComponent(msg));
    }
    , submitInternalIframe : function (channelEsc, msg) {
        var doc = this.submitIframe.contentWindow.document;
        doc.body.innerHTML = "";
        if (document.all && window.opera == undefined) {
            IFrameUtil.bindEvent(this.submitIframe, 'readystatechange', this.onFormIframeLoaded);
        } else {
            IFrameUtil.bindEvent(this.submitIframe, 'load', this.onFormIframeLoaded);
        }

        var form = doc.createElement('form');
        form.acceptCharset = "Shift_JIS";
        form.action = Mobirc.docroot + 'mobile-ajax/channel?channel=' + encodeURIComponent(channelEsc);
        form.method = 'POST';
        var input = doc.createElement('input');
        input.name = 'msg';
        input.value = msg;
        form.appendChild(input);
        doc.body.appendChild(form);
        form.submit();
    }
    , onFormIframeLoaded : function (sender) {
        // on submit
        try {
            eval(SubmitUtil.submitIframe.contentWindow.document.body.innerHTML);
        } catch (e) { Mobirc.onTick(); }
    }
};

var Mobirc = {
    docroot   : ___docroot,
    interval  : 15 * 1000,
    useIFrame : true,

    timerId   : null,

    setUp : function () {
        this.channelIframe = this.createInheritedIframe('channel-iframe-container');
        this.recentLogIframe = this.createInheritedIframe('recentlog-iframe-container');
        SubmitUtil.setUp();

        // nice tenuki.
        setTimeout(function() {
            SubmitUtil.initialize();
            Mobirc.initialize();
            Mobirc.startInterval();
        }, 5000);
    }
    , initialize : function () {
        try {
            // Reference Error: Opera 8.6 (au)
            this.recentDoc.charset = document.charset;
            this.channelDoc.charset = document.charset;
        } catch (e) { }

        var styleSheet = document.getElementById("stylesheet");
        if (!this.channelIframe.init) this.channelIframe.contentWindow.document.writeln("<style type='text/css'>"+styleSheet.value+"</style><body><ul class='log' id='lines'><li>Loading</li></ul></body>");
        if (!this.recentLogIframe.init) this.recentLogIframe.contentWindow.document.writeln("<style type='text/css'>"+styleSheet.value+"</style><body><ul class='log' id='lines'><li>not implemented yet</li></ul></body>");

        this.channelIframe.contentWindow.document.getElementById('lines').innerHTML = "";
        this.recentLogIframe.contentWindow.document.getElementById('lines').innerHTML = "";
        this.onChangeChannel();
        // TODO: re-implement
        // this.requestJsonp('mobile-ajax/recent', true);
    }
    , createFormIframe : function (container) {
        var styleSheet = document.getElementsByTagName("style")[0];
        var iframe = IFrameUtil.createAndInsertIframe(container, this.onFormIframeLoaded, false);
        //iframe.contentWindow.document.charset = "Shift_JIS";
        //iframe.contentWindow.document.writeln("<body></body>");
        return iframe;
    }
    , createInheritedIframe : function (container) {
        var styleSheet = document.getElementsByTagName("style")[0];
        var iframe = IFrameUtil.createAndInsertIframe(container, this.onInheritedIframeCreated, false);
        if (iframe.contentWindow) {
            iframe.init = true;
            iframe.contentWindow.document.charset = "Shift_JIS";
            iframe.contentWindow.document.writeln("<style type='text/css'>"+styleSheet.innerHTML+"</style><body><ul class='log' id='lines'><li>Loading</li></ul></body>");
        }
        return iframe;
    }
    , onInheritedIframeCreated : function (sender) {
    }
    , requestJsonp : function (path, recent)
    {
        var joinner = (path.indexOf('?') == -1) ? '?' : '&';
        var uri = this.docroot + path + joinner + 't=' +(new Date()).valueOf();

        if (window.XMLHttpRequest) {
            XHRUtil.requestJsonp(uri);
        } else if (this.useIFrame) {
            IFrameUtil.jsonpContainerId = "jsonp-container";
            IFrameUtil.requestJsonp(uri);
        } else {
            var script = document.createElement('script');
            script.setAttribute('type', 'text/javascript');
            script.setAttribute('src', uri);
            //script.setAttribute('charset', 'UTF-8');
            var scripts = document.getElementById('jsonp-container');
            scripts.appendChild(script);
        }
    }
    , startInterval : function () {
        this.stopInterval();
        this.timerId = setInterval(this._onTick, this.interval);
    }
    , stopInterval : function () {
        if (this.timerId) {
            clearInterval(this.timerId);
            this.timerId = null;
        }
    }
    , onChangeChannel : function () {
        this.stopInterval();
        this.channelIframe.contentWindow.document.getElementById('lines').innerHTML = "";
        this.requestJsonp('mobile-ajax/channel?channel=' + encodeURIComponent(document.getElementById('channel').value));
        this.startInterval();
    }
    , _onTick : function () { Mobirc.onTick(); }
    , onTick : function () {
        this.requestJsonp('mobile-ajax/channel?recent=1&channel=' + encodeURIComponent(document.getElementById('channel').value));
        // this.requestJsonp('mobile-ajax/recent', true); TODO: reimplement
    }
    , onSubmit : function () {
        try {
            var msg = document.getElementById('msg');
            SubmitUtil.submit(document.getElementById('channel').value, msg.value);
            msg.value = "";
        } catch (e) { alert(e.description || e.toString()); }
        return false;
    }
    , onClick : function (e) {
        var a = (e.target || e.srcElement);
        Mobirc.selectChannel(a.title);
        return false;
    }
    , callbackChannel : function (lines) {
        if (lines != null && lines.length < 1)
            return;

        var doc = this.channelIframe.contentWindow.document;
        var ul = doc.getElementById('lines');

        var html = "";
        for (var i = 0, n = lines.length; i < n; i++) {
            html += "<li>"+this.unescapeHTML(lines[i])+"</li>";
        }
        ul.innerHTML = html + ul.innerHTML;
        if (ul.childNodes.length > 50) {
            ul.removeChild(ul.lastChild);
        }
    }
    // DOM
    , callbackChannel__ : function (lines) {
        if (lines != null && lines.length < 1)
            return;

        var doc = this.channelIframe.contentWindow.document;
        var ul = doc.getElementById('lines');

        for (var i = lines.length-1; i >= 0; i--) {
            var li = doc.createElement('li');
            li.innerHTML = this.unescapeHTML(lines[i]);
            ul.insertBefore(li, ul.firstChild);
        }
        if (ul.childNodes.length > 50) {
            ul.removeChild(ul.lastChild);
        }
    }
    , callbackRecent : function (recents) {
        if (recents != null && recents.length < 1)
            return;

        try {
        var doc = this.recentLogIframe.contentWindow.document;
        var ul = doc.getElementById('lines');

        for (var n = 0; n < recents.length; n++) {
            var lines = recents[n].lines;
            for (var i = 0, j = lines.length; i < j; i++) {
                var a = doc.createElement('a');
                a.appendChild(doc.createTextNode(recents[n].channel));
                a.title = recents[n].channel_enc;
                a.href = "javascript:";
                if (a.addEventListener) {
                    a.addEventListener('click', this.onClick, false);
                } else if (a.attachEvent) {
                    a.attachEvent('onclick', this.onClick);
                }

                var li = doc.createElement('li');
                li.innerHTML = "> " + this.unescapeHTML(lines[i]);
                li.insertBefore(a, li.firstChild);
                ul.insertBefore(li, ul.firstChild);
            }
            if (ul.childNodes.length > 50) {
                ul.removeChild(ul.lastChild);
            }
        }
        } catch (e) { alert(e); }
    }
    , selectChannel : function (chanUriName) {
        var select = document.getElementById('channel');
        select.value = chanUriName;
        for (var i = 0; i < select.options.length; i++) {
            select.options[i].selected = (select.options[i].value == chanUriName);
        }
        this.onChangeChannel();
    }
    , unescapeHTML : function (s) {
        return (s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&'));
    }
};

var XHRUtil = {
    requestJsonp : function (path) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", path, true);
        xhr.onreadystatechange = function () {
            if (xhr.readyState == 4 && xhr.status >= 200 && xhr.status < 400) {
                eval(xhr.responseText);
            }
        }
        xhr.send(null);
    }
};

var IFrameUtil = {
    jsonpContainerId  : "container"
    , iframe : null
    , requestQueue : []

    , createAndInsertIframe : function (containerId, onloadHandler, requireInit) {
        var e = document.createElement("iframe");
        document.getElementById(containerId).appendChild(e);

        if (document.all && window.opera == undefined) {
            this.bindEvent(e, 'readystatechange', function () { if (e.readyState == "complete" && onloadHandler) onloadHandler(e);});
        } else {
            this.bindEvent(e, 'load', function () { if (onloadHandler) onloadHandler(e);});
        }

        if (requireInit)
            e.contentWindow.document.writeln("<html><body></body></html>");

        return e;
    }

    , bindEvent : function (E, eventName, handler) {
    if (E.addEventListener) {
        E.addEventListener(eventName, handler, false);
    } else if (E.attachEvent) {
        E.attachEvent('on'+eventName, handler);
    }
    }

    , requestJsonp : function (path) {
        if (this.iframe == null) {
            this.iframe = this.createAndInsertIframe(this.jsonpContainerId, IFrameUtil.onLoad_, false);
            this.iframe.style.display = 'none';
        }

        this.requestQueue.push(path);
        if (this.requestQueue.length == 1) {
            this.processNextRequest();
        }

        return this.iframe;
    }

    , onLoad_ : function () { IFrameUtil.onLoad(event.srcElement || event.target); }
    , onLoad  : function (sender) {
        try {
            eval(sender.contentWindow.document.body.innerHTML);
        } catch (e) {};
        if (this.iframe.src != "") {
            this.requestQueue.shift();
            this.processNextRequest();
        }
    }

    , processNextRequest : function () {
        if (this.requestQueue.length > 0) {
            this.iframe.src = this.requestQueue[0];
        }
    }
};

Mobirc.setUp();
