import * as CursorHelpers from "./cursor_helpers.js"
import * as VnHelpers from "./vn_helpers.js"

document.addEventListener("keyup", mapKeysForMe);

var prevC;

async function mapKeysForMe(event) {
    CursorHelpers.saveLastCursor('mapKeysForMe');

    // Android's keyCode: enter = 13; backspace = 8; others are all 229
    if (event.code == '' && (event.key == 'Backspace' || event.keyCode == 8)) { 
        event.code = 'Backspace';
        prevC = null;
    }
    
    // let logStr = `keyup: key='${event.key}' | code='${event.code}' | keyCode=${event.keyCode}`;
    // console.log(logStr); // console.log(controlKeys.includes(event.code));

    // Skip control keys
    if (event.code != "" && controlKeys.includes(event.code)) { 
        // console.log("controlKey found:", event.code);
        return; 
    }

    // Bỏ qua phím Enter
    if (event.key == 'Enter' || event.keyCode == 13) { 
        event.preventDefault();
        return;
    }

    var s = window.getSelection();
    let i = s.anchorOffset;
    var p = document.getElementById('texteditor');
    var t = p.textContent;
    let c1 = event.keyCode == 32 ? 32 : t.charCodeAt(i-1);
    let c2 = prevC;
    prevC = c1;
    
    let l = t.substr(0, i);
    let r = t.substr(i,);

    // Press space will auto-complete sent
    if (c1 === 32 || c1 === 160) { // Android space char code is 160
        if (c2 === 32 || c2 === 160) { // Double-space
            console.log(" > > Double spaces < <");
        }
        // TODO: Hiển thị lựa chọn nguyên bản
        return;
    }    

    let lastWord = l.trim().split(/\s+/).slice(-1)[0];

    // Process telex input method
    var newl;
    let lastChar = String.fromCharCode(c1);
    lastChar = event.code === "backspace" ? null 
        : lastWord.slice(-1) === lastChar ? lastChar : null;
    // console.log('lastChar',lastChar, lastWord.slice(-1), String.fromCharCode(c1));
    if (c2 != 32 && c2 != 160 && lastChar && 
        (true || "dsfrxj eoazqw".includes(lastChar) || c1 === 160)) {
        let newWord = VnHelpers.telexifyWord(lastWord);
        // console.log('TELEX:',lastWord,'=>',newWord);
        if (newWord !== lastWord) {
            newl = l.substr(0,l.length - lastWord.length) + newWord;
            p.firstChild.textContent = newl + r;
            CursorHelpers.collapse(s, p.firstChild, 
                CursorHelpers.setLastCursorFast(newl.length));
            l = newl;
        }
    }

    // console.log(c1,c2,prevC);
}
