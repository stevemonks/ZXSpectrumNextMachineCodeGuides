// Function to handle dropping a document on the webpage.
// In this example, this is set up to expect a JSON document exported from TileEd.
function onDropHandler(event)
{
    console.log(JSON.stringify(event));

    var dt = event.dataTransfer;
    var files = dt.files;
    var items = dt.items;

    var file = items[0].getAsFile();

    console.log(""+file);
    var reader = new FileReader();
    reader.onload = function(event) {
        var contents = event.target.result;
        try {
            // parse the dropped document from JSON into an object
            var tileMapData = JSON.parse(contents);
            // convert the object into an ASM representation
            convertToASM(file.name, tileMapData);
            console.log("read file");
        }
        catch(e) {
            console.log(e);
        }
    }
    reader.readAsText(file);
}



// function to "download" a document from the webpage
function download(data, filename, type)
{
    var a = document.createElement("a"),
        file = new Blob([data], {type: type});
    if (window.navigator.msSaveOrOpenBlob) // IE10+
        window.navigator.msSaveOrOpenBlob(file, filename);
    else { // Others
        var url = URL.createObjectURL(file);
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        setTimeout(function() {
            document.body.removeChild(a);
            window.URL.revokeObjectURL(url);
        }, 0);
    }
}

// This function converts the JSON representation of the document into ASM source.
// The expectation here is that the TileEd file will contain a single layer and contain
// less than 256 types of tile.
function convertToASM(fileName, fileData)
{
    var outString = "";
    var fileNameParts = fileName.split(".");
    var outName = fileNameParts[0] + ".s";

    // generate a label formed from the original dropped filename with a "_map" suffix
    outString = outString + fileNameParts[0] + "_map:\r";
    // prefix the RLE data with two bytes describing how wide and high the map was in tiles.
    outString = outString + "\tdb "+fileData.layers[0].width+","+fileData.layers[0].height+"\r";

    // RLE compress srcArray, returning the compressed data in dstArray
    var srcArray = [];
    for (var ix in fileData.layers[0].data) {
        // TileEd starts tile indices at 1, with empty spaces marked with a zero.
        // As we want our data to map directly to Next tile indices, we need to decrement
        // every tile index by 1.
        var v = fileData.layers[0].data[ix];
        var newV = v > 0 ? v-1 : 0;
        srcArray.push(newV);
    }
    var dstArray = CompressRLE(srcArray);

    // serialise the contents of dstArray as lines of ASM 'db' statements
    var cnt = 0;
    var prefix = "";
    for (var ix = 0; ix < dstArray.length; ix++) {
        if (cnt == 32) {
            cnt = 0;
            outString = outString + "\r";
            prefix = "";
        }
        if (cnt == 0) {
            outString = outString + "\tdb ";
        }
        outString = outString + prefix + dstArray[ix];
        prefix = ",";
        cnt++;
    }
    outString = outString + "\r";

    // having generated the complete ASM output file in outString, we can now trigger
    // a download of it as a text file.
    download(outString,outName,"text");
    var mainDiv = document.getElementById('mainDiv');
    mainDiv.innerText = outString;
}



// This function RLE compresses the contents of srcArray. The expectation is that this
// will contain a stream of numbers between 0 and 255.
// An array is returned containing the compressed data.
//
// This function is pretty generic and can be used to compress any suitable data.
//
function CompressRLE(srcArray)
{
    // rle export
    var dstArray = [];
    var srcLen = srcArray.length;
    var ix = 0;
    var copyBuff = [];
    while(ix < srcLen) {
        var cnt = 1;
        var curr = srcArray[ix];
        while(ix < srcLen && cnt < 128) {
            if (srcArray[ix+cnt] != curr) {
                break;
            }
            cnt++;
        }

        if (cnt < 3) {  // if there were less than 3 repeats add to the copy buffer
            if (copyBuff.length + cnt > 127) {
                // copybuffer is full or will overflow, so flush it by appending it to the output
                dstArray.push(copyBuff.length); // prefix with positive length
                dstArray = dstArray.concat(copyBuff);
                copyBuff = [];
            }
            while(cnt >= 0) {
                if (ix >= srcLen) {
                    break;
                }
                cnt--;
                copyBuff.push(srcArray[ix++]);
            }
        }
        else {  // add a repeat run
            if (copyBuff.length > 0) {          // flush anything currently in the copy buffer
                dstArray.push(copyBuff.length); // prefix with positive length
                dstArray = dstArray.concat(copyBuff);
                copyBuff = [];
            }
            dstArray.push(-(cnt));  // prefix with positive length
            dstArray.push(curr);    // add the byte to repeat
            ix += cnt;
        }
    }

    // flush anything left over in the copy buffer
    if (copyBuff.length > 0) {          // flush anything currently in the copy buffer
        dstArray.push(copyBuff.length); // prefix with positive length
        dstArray = dstArray.concat(copyBuff);
        copyBuff = [];
    }
    dstArray.push(0);   // add a terminator to the RLE data

    return dstArray;

}