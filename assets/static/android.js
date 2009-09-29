function http (opts) {
	var d = Deferred();
	var req = new XMLHttpRequest();
	req.open(opts.method, opts.url, true);
	if (opts.headers) {
		for (var k in opts.headers) if (opts.headers.hasOwnProperty(k)) {
			req.setRequestHeader(k, opts.headers[k]);
		}
	}
	req.onreadystatechange = function () {
		if (req.readyState == 4) d.call(req);
	};
	req.send(opts.data || null);
	d.xhr = req;
	return d;
}
http.get   = function (url)       { return http({method:"get",  url:url}) };
http.post  = function (url, data) { return http({method:"post", url:url, data:data, headers:{"Content-Type":"application/x-www-form-urlencoded"}}) };
http.jsonp = function (url, params) {
	if (!params) params = {};

	var Global = (function () { return this })();
	var d = Deferred();
	var cbname = params["callback"];
	if (!cbname) do {
		cbname = "callback" + String(Math.random()).slice(2);
	} while (typeof(Global[cbname]) != "undefined");

	params["callback"] = cbname;

	url += (url.indexOf("?") == -1) ? "?" : "&";

	for (var name in params) if (params.hasOwnProperty(name)) {
		url = url + encodeURIComponent(name) + "=" + encodeURIComponent(params[name]) + "&";
	}

	var script = document.createElement('script');
	script.type    = "text/javascript";
	script.charset = "utf-8";
	script.src     = url;
	document.body.appendChild(script);

	Global[cbname] = function callback (data) {
		delete Global[cbname];
		document.body.removeChild(script);
		d.call(data);
	};
	return d;
};


new function inputOperation () {
    var form = document.getElementById("input");
    if (form) {
        var input = form.querySelector("input[name=msg]");

        form.addEventListener("submit", function (e) {
            e.preventDefault();

            input.disabled = true;
            input.style.background = "#ccc";

            var img = document.createElement("img");
            img.className = "loading";
            img.src = docroot + "static/loading.gif";

            form.appendChild(img);

            $.post(form.action, {
                msg : input.value
            }, function (data) {
                input.value = "";
                location.replace(location.href);
            });
        }, false);

        var selects = document.querySelectorAll("select.operations");
        for (var i = 0, len = selects.length; i < len; i++) {
            with ({select : selects[i]}) select.addEventListener("change", function (e) {
                input.value = select.value;
                input.focus();
                scrollTo(0, 0);
            });
        }
    }
};

new function pager () {
    var loading = false;

    var content  = document.getElementById('content');
    var nextLink = document.querySelector("a[rel='next']");

    window.addEventListener('scroll', function (e) {
        if (loading) return;

        var height = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight);
        var remain = height - window.innerHeight - window.scrollY;
        if (remain < 100 + window.innerHeight) {
            loading = true;
            if (nextLink) {
                nextLink.innerHTML = "loading...";
                http.get(nextLink.href).next(function (xhr) {
                    var tmp = document.createElement('div');
                    tmp.innerHTML = xhr.responseText;
                    var page = tmp.querySelectorAll("#content > *");
                    if (page.length) {
                        for (var i = 0, len = page.length; i < len; i++) {
                            content.appendChild(page[i]);    
                        }
                        nextLink.href = tmp.querySelector("a[rel='next']").href;
                        loading = false;
                    } else {
                        nextLink.parentNode.removeChild(nextLink);
                    }
                });
            } else {
                window.removeEventListener('scroll', arguments.callee, false);
            }
        }
    }, false);
};


new function historyControl () {
    var more = document.querySelectorAll('div.more a');
    for (var i = 0, len = more.length; i < len; i++) {
        var href = more[i].href;
        more[i].href = 'javascript:location.replace("'+href+'")';
    }
};
