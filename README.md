# Deploy to Wasm

Tham khảo UI/UX https://languagetool.org/editor/new

### Getting started

- Create a deps.zig by running `gyro fetch`
- Build wasm payload with `zig build`
- `npm install` to setup vite dependencies
- `npm run dev` to start your dev server
- Point your browser at `localhost:3000`


## Benefit of Wasm

> force developers to work within tech and design limitations. by removing excess and focusing 
> on the essential, it becomes easier to start and finish developing a game. This is in 
> contrast to large game engines, which can be daunting and distracting.
https://wasm4.org/docs/#why-wasm-4

__NOTE__: Bộ nhớ wasm nhỏ, nền web, data bự load xuống local khó trôi nên cần sử dụng những models có dung lượng nhỏ. Full n-gram chiếm vài trăm MB không còn thích hợp. Các lựa chọn khác bao gồm:

* Pattern matching (dùng filter chiếm vài trăm kb)
* Rule-based (hard-coded)
* Pointwise (SVM, tree/forest ...)
* Selected n-gram (31.7 MB of 2,3,4-gram tinh gọn)

## Module 3a/ Bộ gõ telex cải tiến trên nền web

[>> DOING <<]

* Hiện lựa chọn tiếng Việt và nguyên gốc `more|moẻ` double space để dùng nguyên gốc

* Nếu từ không phải tiếng Việt thì chỉ hiển thị nguyên gốc

* Dùng `q hoặc z` để loại bỏ dấu và thanh

[>> DONE <<]

* Phân tích https://phiresky.github.io/blog/2021/hosting-sqlite-databases-on-github-pages
  Query a dataset with 6 tables and over 8 million rows (670 MiByte total) need to fetch 10k data only! => wasm load data remotely chunk by chunk!

* Tìm hiểu texteditor in Zig (xem `.save`)
  https://viewsourcecode.org/snaptoken/kilo
  https://github.com/paulsmith/texteditor-zig/blob/main/src/main.zig
  https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm

* Tách phần code từ `stp/e` ra để có ngay một bộ gõ đơn giản, có các tính năng nâng cao ở dạng prototye và cải tiến từ đấy

* Sử dụng `simple.css` https://raw.githubusercontent.com/kevquirk/simple.css/main/simple.css


- - - - - - - - - - - - - - -
 

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


- - - - - - - - - - - - - - -


## PHỤ LỤC

### 3c.1: Dữ liệu từ điển âm tiết tiếng Việt

Thống kê từ điển thấy rằng từ tiếng Việt bao gồm: 
* `16%` một âm tiết
* `71%` hai âm tiết
* `13%` là 3+ âm tiết

Nếu bỏ từ một âm tiết, thì số lượng 3+ âm tiết chiếm khoảng 15%.

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
```
count=1 => `10_956_634` 3-grams => `12mb BinaryFuse(u8)`  (`x*9/(8*1024*1024)`)
count=2 => ` 2_345_545` 3-grams => ` 5mb BinaryFuse(u16)` (`x*18/(8*1024*1024)`)
remains => ` 4_000_183` 3-grams => `24mb HashCount`       (2^22 x 6-bytes)
TOTAL: 41MB,
```
=> Mỗi lookup cần đối chiếu với 2 filters và 1 hash_count. Cách này cân bằng giữa MEM và CPU!


Loại count = 1 và quantization về khoảng 8 nhóm để tiết kiệm MEM ta được:
```
o/ count=0,1
a/ count=02     => `2_343_228` 3-grams => `2.5 mb BinaryFuse(u8)`
b/ count=03..05 => `1_995_402` 3-grams => `4.3 mb BinaryFuse(u16)`
c/ count=06..11 => `  955_810` 3-grams => `2.0 mb BinaryFuse(u16)`
d/ count=12..25 => `  533_752` 3-grams => `1.2 mb BinaryFuse(u16)`
e/ count=25..80 => `  339_218` 3-grams => `0.7 mb BinaryFuse(u16)`
f/ remain       => `  174_532` 3-grams => `0.4 mb BinaryFuse(u16)`
   TOTAL: 11.1 MB
```
#### 2-gram
```
a/ count=1,2    => `1_444_334` 2-grams => `1.5 mb BinaryFuse(u8)`
b/ count=03..05 => `  424_429` 2-grams => `1.0 mb BinaryFuse(u16)`
c/ count=06..11 => `  276_007` 2-grams => `0.6 mb BinaryFuse(u16)`
d/ count=12..25 => `  199_301` 2-grams => `0.4 mb BinaryFuse(u16)`
e/ count=25..80 => `  170_952` 2-grams => `0.4 mb BinaryFuse(u16)`
f/ remain       => `  150_211` 2-grams => `0.3 mb BinaryFuse(u16)`
TOTAL: 4.2 MB
```

#### 4-gram
```
a/ count=2      => `4_407_945` 4-grams => `4.7 mb BinaryFuse(u8)`
b/ count=03..05 => `3_114_767` 4-grams => `6.7 mb BinaryFuse(u16)`
c/ count=06..11 => `1_252_778` 4-grams => `2.7 mb BinaryFuse(u16)`
d/ count=12..25 => `  601_206` 4-grams => `1.3 mb BinaryFuse(u16)`
e/ count=25..80 => `  322_523` 4-grams => `0.7 mb BinaryFuse(u16)`
f/ remain       => `  121_206` 4-grams => `0.3 mb BinaryFuse(u16)`
TOTAL: 16.4 MB
```

#### Chiến thuật load n-gram filters

Bé load trước, lớn load sau, load song song 3 filter cùng loại 1 lúc
```
2f 3f 4f =  1.0 mb
2e 3e 4e =  1.8 mb
2d 3d 4d =  2.9 mb
2c 3c 4c =  5.3 mb
2a 3a 4a =  8.7 mb
2b 3b 4b = 12.0 mb
```

#### Cách tính điểm khi so khớp với chuỗi tokens đầu vào
```
o/ 01 điểm
a/ 02 điểm
b/ 04 điểm
c/ 08 điểm
d/ 16 điểm
e/ 32 điểm
f/ 64 điểm
```
=> !!! Cần đo xem cách tách thô này làm giảm độ hiệu quả của mô hình đi bao nhiêu ???
