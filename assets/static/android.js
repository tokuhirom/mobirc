
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

var more = document.querySelectorAll('div.more a');
for (var i = 0, len = more.length; i < len; i++) {
    var href = more[i].href;
    more[i].href = 'javascript:location.replace("'+href+'")';
}

