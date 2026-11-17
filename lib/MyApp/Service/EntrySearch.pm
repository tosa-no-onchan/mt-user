package MyApp::Service::EntrySearch;
use strict;
use warnings;

use MyApp::ToolMy;

sub new {
    my ($class, %args) = @_;
    die "entry_model is required" unless $args{entry_model};
    return bless { entry_model => $args{entry_model} }, $class;
}

sub category_search{
    my ($self, $blog_id, $raw_keyword, $category,$limit, $offset) = @_;

    my $count = $self->{entry_model}->category_count($blog_id, $raw_keyword,$category);

    if ($count==0){
        return (0,[]);
    }

    my $entries = $self->{entry_model}->serach_by_catregory($blog_id, $raw_keyword, $category,$limit, $offset);

    my $results = $self->ref2list($entries);
    #  $sql = $self->make_sql($blog_id, $keyword,1);
    return ($count,$results);
}

sub keyword_search {
    my ($self, $blog_id, $raw_keyword, $limit, $offset) = @_;
    $raw_keyword //= '';
    $raw_keyword =~ s/^\s+|\s+$//g; # 前後の空白を除去

    my $count = $self->{entry_model}->get_entries_count($blog_id, $raw_keyword);

    #MyApp::ToolMy::exitError("MyApp::Service::EntrySearch::execute #1 \$count.".$count);

    if ($count==0){
        return (0,[]);
    }

    my $entries = $self->{entry_model}->search_entries($blog_id, $raw_keyword, $limit, $offset);

    if(0){
        # ★デバッグ出力（標準エラー出力へダンプ）
        #use Data::Dumper;
        #local $Data::Dumper::Indent = 1;
        #local $Data::Dumper::Sortkeys = 1;
        #warn Dumper($entries);

        # ★デバッグ出力（見やすく整形して出力）
        warn "=== 検索ヒット件数: " . scalar(@$entries) . " 件 ===\n";
        for my $e (@$entries) {
            #warn Dumper($e);
            #exit(0);
            warn sprintf(
                "[ID:%s] %s | 日時:%s | URL:%s\n",
                $e->id          // 'undef',
                $e->title       // '(無題)',
                $e->authored_on // '',
                $e->url         // '(URLなし)',
                $e->author_nickname,
                $e->author_name,
            );
        }
    }

    my $results = $self->ref2list($entries);
    return ($count,$results);
}

sub ref2list{
    #my ($self, $blog_id, $raw_keyword, $limit, $offset) = @_;
    my ($self, $entries) = @_;

    my @results;
    for my $entry (@$entries) {
        # 本文からHTMLタグを除去し、100文字の抜粋を作成
        my $excerpt = $entry->text;
        #$excerpt =~ s/<[^>]+>//g;
        #$excerpt =~ s/\s+/ /g;
        #$excerpt = substr($excerpt, 0, 100) . '...' if length($excerpt) > 100;

        # MTの日付形式 (YYYYMMDDHHMMSS) を YYYY-MM-DD に整形
        my $date = $entry->authored_on;
        $date =~ s/^(\d{4})(\d{2})(\d{2}).*/$1-$2-$3/;

        # URLが取れなかった場合のフォールバック
        my $url = $entry->url || ('/blog/entry-' . $entry->id . '.html');

        push @results, {
            id      => $entry->id,
            title   => $entry->title || '(無題)',
            excerpt => $excerpt,
            date    => $date,
            url     => $url,
            author  => $entry->author_nickname || $entry->author_name || '不明',
            text_more_lng => $entry->get_text_more_lng(),
        };
    }
    return \@results;
}

1;