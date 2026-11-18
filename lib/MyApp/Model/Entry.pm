package MyApp::Model::Entry;
use strict;
use warnings;

use MyApp::ToolMy;

sub new {
    my ($class, %args) = @_;
    die "dbh is required" unless $args{dbh};
    return bless { dbh => $args{dbh} }, $class;
}

# category の SQL
# 'join' => [ 'MT::Placement', undef, { 'entry_id' => \'= entry_id', 'blog_id' => \'= entry_blog_id' }, { 'unique' => 1, 'join' => [ 'MT::Category', undef, [ [ { 'label' => 'ROS2' } ], '-and', { 'blog_id' => \'= entry_blog_id', 'id' => \'= placement_category_id' } ], {} ] } ], 
#
# SELECT COUNT(*) FROM (SELECT DISTINCT entry_id FROM mt_entry, mt_placement, mt_category WHERE (entry_blog_id IN (?) AND entry_status = ?) AND (placement_blog_id = entry_blog_id) AND (placement_entry_id = entry_id) AND ((category_label = ?)) AND (category_blog_id = entry_blog_id AND category_id = placement_category_id) ) t
# SELECT DISTINCT entry_id FROM mt_entry, mt_placement, mt_category WHERE (entry_blog_id IN (?) AND entry_status = ?) AND (placement_blog_id = entry_blog_id) AND (placement_entry_id = entry_id) AND ((category_label = ?)) AND (category_blog_id = entry_blog_id AND category_id = placement_category_id) ORDER BY entry_authored_on DESC LIMIT 20 OFFSET 20

#-------
# category_count()
# $category と $keyword による、検索の件数取得
# $keyword='' が、全件検索です!
#-------
sub category_count {
    my ($self, $blog_id, $keyword, $category) = @_;
    my $sql;
    my $bind;

    ($sql, $bind) = $self->make_sql_category($blog_id, $keyword, $category,1);

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute(@{$bind});
    my ($count) = $sth->fetchrow_array;
    return $count // 0;
}

#-------
# serach_by_catregory()
# $category と $keyword による、検索
# $keyword='' が、全件検索です!
#-------
sub serach_by_catregory{
    my ($self, $blog_id, $keyword, $category, $limit, $offset) = @_;
    my $sql;
    my $bind;

    ($sql, $bind) = $self->make_sql_category($blog_id, $keyword, $category);

    # 3. 並び順とページネーションを追加
    $sql .= q{ ORDER BY e.entry_authored_on DESC LIMIT ? OFFSET ? };

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute(@{$bind},$limit, $offset);

    my @entries;
    while (my $row = $sth->fetchrow_hashref) {
        push @entries, MyApp::Entity::Entry->new(%$row);
    }
    return \@entries;
}

#-------
# search_entries()
# $keyword による、検索
# $keyword='' が、全件検索です!
#-------
sub search_entries {
    my ($self, $blog_id, $keyword, $limit, $offset) = @_;

    #return [] unless defined $keyword && $keyword ne '';
    my $sql='';
    my $bind;

    #MyApp::ToolMy::exitError("MyApp::Molde::Entry::search_entries #2");

    my $order_by =q{
        ORDER BY e.entry_authored_on DESC
        LIMIT ? OFFSET ?
    };

    ($sql, $bind) = $self->make_sql($blog_id, $keyword);
    $sql = $sql.$order_by;

    my $sth = $self->{dbh}->prepare($sql);

    $sth->execute(@{$bind},$limit, $offset);

    my @entries;
    while (my $row = $sth->fetchrow_hashref) {
        push @entries, MyApp::Entity::Entry->new(%$row);
    }
    return \@entries;
}

#-------
# get_entries_count()
# $keyword による、検索 の件数取得
# $keyword='' が、全件検索です!
#-------
sub get_entries_count {
    my ($self, $blog_id, $keyword) = @_;
    #return [] unless defined $keyword && $keyword ne '';
    my $sql;
    my $bind;

    ($sql, $bind) = $self->make_sql($blog_id, $keyword,1);
    #MyApp::ToolMy::exitError("MyApp::Molde::Entry::get_entries_count #1 \$sql:".$sql,1);

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute(@{$bind});
    my ($count) = $sth->fetchrow_array;

    #MyApp::ToolMy::exitError("MyApp::Molde::Entry::get_entries_count #9 \$count:".$count,1);
    return $count;
}
#------------
# make_sql():
# keyword 検索時の $sql 文を作成する!!
# $flg : '' / 1 ->  データ収集 / 件数取得 
# $keyword : '' -> 全件検索
# $keyword : '%' -> '\%' を検索する。
#------------
sub make_sql {
    my ($self, $blog_id, $keyword, $flg) = @_;
    my $op  = 'OR';
    my $not = '';
    $keyword //= ''; # undef対策
    if ($keyword =~ s/^!//) {
        $op  = 'AND';
        $not = 'NOT';
    }
    # ワイルドカード文字をエスケープする
    $keyword =~ s/([%_\\])/\\$1/g;
    my $like_val = '%' . $keyword . '%';
    my $where = qq{
        WHERE e.entry_blog_id = ?
          AND e.entry_status = 2
    };
    # バインドする値も一緒に返すと便利
    my @bind = ($blog_id);

    my $sql;
    if (!defined $flg) {
        $sql = qq{
            SELECT e.*, f.fileinfo_url,
                a.author_nickname,
                a.author_name
            FROM mt_entry e
            LEFT JOIN mt_fileinfo f
                ON e.entry_id = f.fileinfo_entry_id
                AND f.fileinfo_archive_type = 'Individual'
            LEFT JOIN mt_author a
                ON a.author_id = e.entry_author_id
        };
    } 
    else {
        $sql = qq{
            SELECT COUNT(e.entry_id)
            FROM mt_entry e
        };
    }
    # キーワードが指定されているときだけ LIKE 条件を追加する
    if ($keyword ne '') {
        $where .= qq{
            AND (
                COALESCE(e.entry_title, '') $not LIKE ? ESCAPE '\\'
                $op COALESCE(e.entry_text, '') $not LIKE ? ESCAPE '\\'
                $op COALESCE(e.entry_text_more, '') $not LIKE ? ESCAPE '\\'
            )
        };
        push @bind, $like_val, $like_val, $like_val;
    }
    $sql = $sql.$where;
    return ($sql, \@bind);
}
#------------
# make_sql_category():
# keyword 検索時の $sql 文を作成する!!
# $flg : '' / 1 ->  データ収集 / 件数取得 
# $keyword : '' -> 全件検索
# $keyword : '%' -> '\%' を検索する。
#------------
sub make_sql_category {
    my ($self, $blog_id, $keyword, $category, $flg) = @_;
    my @bind = ($blog_id,$category);
    my $sql;
    # データ収集
    if(!$flg){
        $sql =q{
            SELECT DISTINCT
                e.*, f.fileinfo_url,
                a.author_nickname,
                a.author_name
            FROM mt_entry e
            INNER JOIN mt_placement p
                ON p.placement_entry_id = e.entry_id
                AND p.placement_blog_id = e.entry_blog_id
            INNER JOIN mt_category c
                ON c.category_id = p.placement_category_id
                AND c.category_blog_id = e.entry_blog_id
            LEFT JOIN mt_fileinfo f
                ON f.fileinfo_entry_id = e.entry_id
                AND f.fileinfo_archive_type = 'Individual'
            LEFT JOIN mt_author a
                ON a.author_id = e.entry_author_id
            WHERE e.entry_blog_id = ?
            AND e.entry_status = 2
            AND c.category_label = ?
        };
    }
    else{
        $sql = q{
            SELECT COUNT(DISTINCT e.entry_id)
            FROM mt_entry e
            INNER JOIN mt_placement p
                ON p.placement_entry_id = e.entry_id
                AND p.placement_blog_id = e.entry_blog_id
            INNER JOIN mt_category c
                ON c.category_id = p.placement_category_id
                AND c.category_blog_id = e.entry_blog_id
            WHERE e.entry_blog_id = ?
            AND e.entry_status = 2
            AND c.category_label = ?
        };
    }
    # 2. もしキーワードも指定されていたら AND 条件を追加する
    if (defined $keyword && $keyword ne '') {
        my $op  = 'OR';
        my $not = '';

        $keyword //= ''; # undef対策
        if ($keyword =~ s/^!//) {
            $op  = 'AND';
            $not = 'NOT';
        }
        # ワイルドカード文字をエスケープする
        $keyword =~ s/([%_\\])/\\$1/g;
        my $like_val = '%' . $keyword . '%';

        $sql .= qq{
            AND (
                COALESCE(e.entry_title, '') $not LIKE ? ESCAPE '\\'
                $op COALESCE(e.entry_text, '') $not LIKE ? ESCAPE '\\'
                $op COALESCE(e.entry_text_more, '') $not LIKE ? ESCAPE '\\'
            )
        };
        push @bind, $like_val, $like_val, $like_val;
    }
    return ($sql, \@bind);
}

sub make_sql_old{
    my ($self, $blog_id, $keyword,$flg) = @_;
    my $sql='';
    my $op='OR';
    my $not='';
    #MyApp::ToolMy::exitError("MyApp::Molde::Entry::make_sql #1 \$$flg:".$flg);
    if ($keyword =~ s/^!//) {
        $op='AND';
        $not='NOT';
    }
    #  なし -> データの取得
    if(!defined $flg){
        $sql = qq{
        SELECT e.*, f.fileinfo_url,
            a.author_nickname,
            a.author_name
        FROM mt_entry e
        LEFT JOIN mt_fileinfo f
            ON e.entry_id = f.fileinfo_entry_id
            AND f.fileinfo_archive_type = 'Individual'
        LEFT JOIN mt_author a
            ON a.author_id = e.entry_author_id
        WHERE e.entry_blog_id = ?
          AND e.entry_status = 2
          AND (e.entry_title $not LIKE ? $op e.entry_text $not LIKE ? $op e.entry_text_more $not LIKE ?)
        };
    }
    # 件数の sql
    else{
        $sql = qq{
            SELECT COUNT(e.entry_id)
            FROM mt_entry e
            WHERE e.entry_blog_id = ?
            AND e.entry_status = 2
            AND (e.entry_title $not LIKE ? $op e.entry_text $not LIKE ?  $op e.entry_text_more $not LIKE ?)
        };
    }
    return $sql;
}

1;