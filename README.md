# mt-user  
Movable Type 2.4.x の mt/mt-search.cgi の代替 検索 CGI です。  
SQLite3 版対応です。  
Ubuntu 24.04 Perl と、 X-Server Perl で実行確認しています。  
  
mt-cgi と併置して使います。  

```
/cgi-bin/  
  mt  
  mt-user  
```

#### 1. インストール  
  
    $ cd /home/your-id/www/cgi-bin  
    $ git clone https://github.com/tosa-no-onchan/mt-user.git  
  
    注) cgi-bin/mt と同じ階層に配置してください。  

#### 2. templates/category_navi.txt を作成  
  
/blog/index.html の、左ナビのカテゴリー部分だけ、抽出します。  
  
    extract.cgi の下記、パスを、自分の環境に合わせる。  
    my $in_file  = '../../html/blog/index.html';
    ブラウザーから、実行する。  
    url: http://www.xxx.com/cgi-bin/mt-user/extract.cgi  
    templates/category_navi.txt が作成される。  

#### 3. templates/search-result.tmpl を、カスタマイズ  
  
    自分の mt/mt-search.cgi の表示内容を参考に、完成させる!!  
    同時に、左ナビのカテゴリー一覧部分に、上記 templates/category_navi.txt  
    を、取り込む。  


```
<!-- 左ナビゲーション（サイドバー）の該当箇所 -->
<TMPL_VAR NAME="category_navi">

```


#### 4. 実行  

    ブラウザーから、実行する。  
    URL: http://www.xxx.com/cgi-bin/mt-user/my-search.cgi?search=&IncludeBlogs=1&limit=20  

#### 5. 参照  

  [Movable Type Free版 セキュリティー対策 Ubuntu 24.04 #2](https://www.netosa.com/blog/2026/11/movable-type-free-ubuntu-2404-2.html)  

