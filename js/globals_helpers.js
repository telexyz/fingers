const FROM_VIRTUAL_BUTTON = "FROM_VIRTUAL_BUTTON";

// https://regexr.com/ => to test regex
const END_PHRASE_AND_SENT_REGEX = /(\s*(?:[,;:\n\\\.\?\!]\s*)+)/gm;
const END_SENT_REGEX =            /(\s*(?:[\n\\\.\?\!]\s*)+)/gm;

const controlKeys = "Tab,Capslock,Enter,"+
    "ControlLeft,AltLeft,ShiftLeft,OsLeft,MetaLeft"+
    "ControlRight,AltRight,ShiftRight,OsRight,MetaRight"+
    "ArrowRight,ArrowLeft,ArrowUp,ArrowDown";

// Make console.assert works on all platforms
if (!console.assert) console.assert = function (x) {
  if (x !== true) console.log("Assertion fail!");
  return x;
}

function assertEqual(x, y) {
  let condition = x === y;
  console.assert(condition);
  if (!condition) {
    console.log(x, "!==", y);
  }
};

var isMobileDevice = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
