# Stage-3: Wasm deploy

## Benefit of Wasm

> force developers to work within tech and design limitations. by removing excess and focusing 
> on the essential, it becomes easier to start and finish developing a game. This is in 
> contrast to large game engines, which can be daunting and distracting.
https://wasm4.org/docs/#why-wasm-4

__NOTE__: Bộ nhớ wasm nhỏ, nền web, data bự load xuống local khó trôi nên cần sử dụng những models có dung lượng nhỏ (vài tới vài chục MB). Full n-gram chiếm vài trăm MB không còn thích hợp. Các lựa chọn khác bao gồm:

* Pattern matching (vài trăm kb)
* Rule-based (can be hard coded)
* Pointwise
* Selected n-gram (chỉ trigram chiếm 36-43mb)
* Neural Network (ONNX Runtime Web)

## THE UGLY TRUTH OF WASM

* Thời gian gọi hàm + trao đổi data giữa wasm và js chậm như rùa
* Chưa tìm được cách load data ngoàimột cách hiệu quả

=> !!! Bước đệm triển khai những gì sẽ triển khai cho wasm trên một TextEditor đơn giản viết bằng Zig !!!

## Module 3a/ Làm giao diện web để có đất thử nghiệm bộ gõ

[>> DOING <<]

* Viết texteditor https://viewsourcecode.org/snaptoken/kilo

[>> DONE <<]

* Tách phần code từ `stp/e` ra để có ngay một bộ gõ đơn giản, có các tính năng nâng cao ở dạng prototye và cải tiến từ đấy

* Sử dụng `simple.css` https://raw.githubusercontent.com/kevquirk/simple.css/main/simple.css


- - -


## Module 3b/ Triển khai bộ viet_tknz to wasm
* Gọi được hàm phân tích syllable từ js
* Áp dụng triệt để trong bộ gõ telex cải tiến để gõ song ngữ Anh-Việt
* Ghi nhớ các gõ của người dùng, lập thành pattern database để cải tiến cách gõ


## Module 3c/ Dict matching
* Load từ điển đã được encoded từ server
* Dùng từ điển để làm `syllables2words`
* Dùng từ điển để gợi ý sửa lỗi chính tả
* Phân tích nhanh văn bản để hiểu được patterns người dùng thường gõ là gì

## Module 3d/ Sửa lỗi chính tả, lỗi cú pháp dùng rule-based


- - -

## PHỤ LỤC

### 3c.1: Dữ liệu từ điển âm tiết tiếng Việt

Thống kê từ điển thấy rằng từ tiếng Việt bao gồm: 

* `16%` một âm tiết
* `71%` hai âm tiết
* `13%` là 3+ âm tiết
Nếu bỏ từ một âm tiết, thì số lượng 3+ âm tiết chiếm khoảng 15% (13 / 84)

Thống kê file [`engine/dict/wordlist.txt`](https://github.com/binhvq/vietdict106k)
(mỗi âm tiết cần `u16` (2-bytes) để lưu trữ)

* `64_220` từ 2 âm tiết = 64k * 4-bytes = `256kb`
* `14_786` từ 3 âm tiết = 15k * 6-bytes = ` 90kb`
* `10_258` từ 4 âm tiết = 10k * 8-bytes = ` 80kb`
* ` 3_555`   +5 âm tiết					  - - - -
						    		TOTAL `426KB` (file gốc 1.4MB)
Số lượng 3+ âm tiết chiếm 27.7% (25k / 90k)

=> _Cần dùng 2 data-structures để lưu dict (khoảng 100k từ):_

1/ Dùng`BinaryFuse(u16)` (cỡ `222KB`) để kiểm tra nhanh xem 1 chuỗi syllables có phải là 1 từ trong từ điển hay không?

2/ `IMF Trie` để auto-suggest âm tiết đang gõ dở

Có thể kết hợp với `Trigram Map & Filter` để reranking auto-suggest candidates

### IMF Trie

Thực chất trie cũng là 1 bảng băm tận dụng tính chất lặp lại có quy luật của văn viết. Nếu băm theo syllable thì tốc độ chậm vì số lượng node.children cao. Băm theo ký tự thì độ cao của cây là 6 (trung bình 6 ký tự / âm tiết), số lượng children cũng không ít vì TV gồm a-z và các kí tự có dấu:
 
 * 16 phụ âm `q,r,t,p,s,d,g,h,k,l,x,c,v,b,n,m`
 * 12 nguyên âm không thanh `a,â,ă,e,ê,y,u,ư,i,o,ô,ơ`
 * 60 nguyên âm có dấu (tổ hợp 5 dấu với 12 nguyên âm)
_=> Tổng 88 ký tự_


Dùng cách trình bày kiểu telex thì:

* 16 phụ âm `q,r,t,p,s,d,g,h,k,l,x,c,v,b,n,m`
* 06 nguyên âm không dấu `a,e,y,u,i,o`
* 02 ký tự hỗ trợ bỏ dấu `w,z`
* 02 ký tự hỗ trợ bỏ thanh `f,j`
_=> Tổng 26 ký tự_

Cách trình bày kiểu telex làm độ dài từ tăng lên trung bình gần 2 ký tự so với cách trình bày utf-8. Tức là khiến cây tìm kiếm càng dài hơn nữa. Trung bình 8 ký tự / âm tiết

Dùng phân tích ngữ âm để tách âm tiết TV thành `initial`, `middle`, `final+tone`. Số lượng các nodes là: 25 initial, 25 middle, và 42 final+tone. Độ cao của cây cho mỗi âm tiết là 3.

Tạo 3 loại nodes:

* `IntNode`: mảng children 25 con trỏ tới `MdlNode`
* `MdlNode`: mảng children 42 con trỏ tới `FntNode`
* `FntNode`: mảng children 25 con trỏ tới `IntNode` và `u32` đếm số lần xuất hiện

=> IMF Trie :D


### Trigram Map & Filter

https://github.com/hexops/fastfilter#benchmarks

Dùng trigram để cân bằng giữa độ chính xác và số lượng gram count phải lưu trữ:
count=1 => `10_956_634` 3-grams => `12mb BinaryFuse(u8)`
count=2 => ` 2_345_545` 3-grams => ` 5mb BinaryFuse(u16)`
remains => ` 4_000_183` 3-grams => `24mb HashCount`(2^22 x 6-bytes)

TOTAL: 41MB,

=> Mỗi lookup cần đối chiếu với 2 filters và 1 hash_count. Cách này cân bằng giữa MEM và CPU!


Tách kỹ hơn nữa ta được:
count=1 => `10_956_634` 3-grams => `12mb BinaryFuse(u8)` (`10_956_634*9/(8*1024*1024)`)
count=2 => ` 2_345_545` 3-grams => ` 5mb BinaryFuse(u16)`(`2_345_545*18/(8*1024*1024)`)
count=3 => ` 1_024_192` 3-grams => ` 2mb BinaryFuse(u16)`
count=4 => `   589_105` 3-grams => ` 1mb BinaryFuse(u16)`
count=5 => `   383_368` 3-grams => ` 1mb BinaryFuse(u16)`
remains => ` 2_003_518` 3-grams => `12mb HashCount`(2^21 x 6-bytes)

TOTAL: 35MB,

=> Mỗi lookup cần đối chiếu với 5 filters và 1 hash_count. Tốn CPU gấp đôi!
_NOTE_: Có thể nhóm count=2,3 và count=4,5 vào một filter để tiết kiệt thời gian lookup!
