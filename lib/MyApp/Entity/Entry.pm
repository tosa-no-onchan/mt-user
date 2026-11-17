# ==============================================================================
# 1. Entity層（MTの記事データ1件を表すオブジェクト）
# MT 4.2.x は、下記か?
# mt/lib/MT/Entry.pm
# ==============================================================================
package MyApp::Entity::Entry;
use strict;
use warnings;

# MT::Entry と同様のカラム定義（メタデータ）
my %COLUMN_DEFS = (
    'id'             => 'integer not null auto_increment',
    'blog_id'        => 'integer not null',
    'status'         => 'smallint not null',
    'author_id'      => 'integer not null',
    'allow_comments' => 'boolean',
    'title'          => 'string(255)',
    'excerpt'        => 'text',
    'text'           => 'text',
    'text_more'      => 'text',
    'convert_breaks' => 'string(30)',
    'to_ping_urls'   => 'text',
    'pinged_urls'    => 'text',
    'allow_pings'    => 'boolean',
    'keywords'       => 'text',
    'tangent_cache'  => 'text',
    'basename'       => 'string(255)',
    'atom_id'        => 'string(255)',
    'authored_on'    => 'datetime',
    'week_number'    => 'integer',
    'template_id'    => 'integer',
    'comment_count'  => 'integer',
    'ping_count'     => 'integer',
    'junk_log'       => 'string meta',
    'category_id'    => 'integer',
);

# テーブルのプレフィックス（MT::Object の datasource => 'entry' 相当）
my $PREFIX = 'entry_';

# コンパイル時に %COLUMN_DEFS からゲッター・セッターメソッドを自動生成する
# use された瞬間にメソッドが生成される
{
    no strict 'refs';
    for my $col (keys %COLUMN_DEFS) {
        *{__PACKAGE__ . "::" . $col} = sub {
            my $self = shift;
            # 引数が渡されたら値をセット（セッター）
            $self->{$col} = $_[0] if @_;
            # 値を返す（ゲッター）
            return $self->{$col};
        };
    }
}

# ★ここには %COLUMN_DEFS にない「url」だけ書けばOK（id, title 等は削除してよい）
sub url {
    my $self = shift;
    $self->{url} = $_[0] if @_;
    return $self->{url};
}

sub author_nickname {
    my $self = shift;
    $self->{author_nickname} = $_ if @_;
    return $self->{author_nickname};
}

sub author_name {
    my $self = shift;
    $self->{author_name} = $_ if @_;
    return $self->{author_name};
}

# コンストラクタ
sub new {
    my ($class, %args) = @_;
    my $self = {};
    for my $col (keys %COLUMN_DEFS) {
        # 'entry_title'（DBのカラム名）と 'title'（プロパティ名）のどちらでも受け取れるようにする
        my $db_col = $PREFIX . $col;
        if (exists $args{$db_col}) {
            $self->{$col} = $args{$db_col};
        } elsif (exists $args{$col}) {
            $self->{$col} = $args{$col};
        }
    }
    # fileinfo_url も受け取れるようにする
    $self->{url} = $args{fileinfo_url} // $args{url} // '';
    $self->{author_nickname} = $args{author_nickname} // '';
    $self->{author_name}     = $args{author_name}     // '';

    return bless $self, $class;
}

# MT::Entry にあるような便利メソッドもそのまま追加可能
sub is_published {
    my ($self) = @_;
    return (defined $self->status && $self->status == 2) ? 1 : 0;
}

sub get_text_more_lng{
    my ($self) = @_;
    return length($self->{text_more});
}

1;