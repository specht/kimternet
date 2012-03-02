console.log("Kimternet!");
kim = chrome.extension.getURL("kim.png");
$('img').each(function(index, image) {
    width = $(image).width();
    height = $(image).height();
    if (width > 60 && height > 60)
    {
        pwidth = $(image).width();
        pheight = $(image).height();
        kimwidth = Math.floor(474.0 * (height / 610.0));
        offset = $(image).position();
        $(image).after("<img src='" + kim + "' border='0' style='height: " + height + "px; position: absolute; border: 0; " +
        "left: " + (width - kimwidth + offset.left) + "px; top: " + (offset.top + 1) + "px;' />");
    }
});
