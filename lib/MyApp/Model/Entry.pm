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

sub category_count {
    my ($self, $blog_id, $keyword, $category) = @_;
    my $sql;
    #$sql = q{
    #    SELECT COUNT(*) FROM (SELECT DISTINCT entry_id FROM mt_entry, mt_placement, mt_category 
    #    WHERE (entry_blog_id IN (?) AND entry_status = 2) AND (placement_blog_id = entry_blog_id) AND (placement_entry_id = entry_id) AND ((category_label = ?)) AND (category_blog_id = entry_blog_id AND category_id = placement_category_id) ) t
    #};

    # ★改善1：SQLite3ではサブクエリを使わずに COUNT(DISTINCT e.entry_id) と直接書ける（高速・シンプル）
    # ★改善2：前の search_by_category と同じ明示的な INNER JOIN 構文に統一して可読性を向上
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

    my @bind = ($blog_id, $category);

    # ★追加：$keyword が指定されている場合は AND 条件とバインド変数を追加
    if (defined $keyword && $keyword ne '') {
        $sql .= q{ AND (e.entry_title LIKE ? OR e.entry_text LIKE ?) };
        my $like = '%' . $keyword . '%';
        push @bind, $like, $like;
    }

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute(@bind);
    my ($count) = $sth->fetchrow_array;
    return $count // 0;
}

sub serach_by_catregory{
    my ($self, $blog_id, $keyword, $category, $limit, $offset) = @_;

    my $sql;
    #$sql =q{
    #    SELECT DISTINCT e.entry_id 
    #    FROM mt_entry e, mt_placement, mt_category 
    #    WHERE (e.entry_blog_id IN (?) AND e.entry_status = 2) 
    #    AND (placement_blog_id = e.entry_blog_id) 
    #    AND (placement_entry_id = e.entry_id) AND ((category_label = ?)) 
    #    AND (category_blog_id = e.entry_blog_id 
    #    AND category_id = placement_category_id) 
    #    ORDER BY e.entry_authored_on DESC LIMIT ? OFFSET ?
    #};

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

    my @bind = ($blog_id, $category);

    # 2. もしキーワードも指定されていたら AND 条件を追加する
    if (defined $keyword && $keyword ne '') {
        $sql .= q{ AND (e.entry_title LIKE ? OR e.entry_text LIKE ?) };
        my $like = '%' . $keyword . '%';
        push @bind, $like, $like;
    }

    # 3. 並び順とページネーションを追加
    $sql .= q{ ORDER BY e.entry_authored_on DESC LIMIT ? OFFSET ? };
    push @bind, $limit, $offset;

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute(@bind);

    my @entries;
    while (my $row = $sth->fetchrow_hashref) {
        push @entries, MyApp::Entity::Entry->new(%$row);
    }
    return \@entries;
}


sub search_entries {
    my ($self, $blog_id, $keyword, $limit, $offset) = @_;

    #return [] unless defined $keyword && $keyword ne '';
    my $sql='';

    if (!defined $keyword || $keyword eq '') {
        $keyword="%";
    }
    #MyApp::ToolMy::exitError("MyApp::Molde::Entry::search_entries #2");

    $sql = q{
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
          AND (e.entry_title LIKE ? OR e.entry_text LIKE ? OR e.entry_text_more LIKE ?)
        ORDER BY e.entry_authored_on DESC
        LIMIT ? OFFSET
    };

    my $order_by =q{
        ORDER BY e.entry_authored_on DESC
        LIMIT ? OFFSET ?
    };

    $sql = $self->make_sql($blog_id, $keyword);
    $sql = $sql.$order_by;

    my $sth = $self->{dbh}->prepare($sql);

    my $like = '%' . $keyword . '%';
    $sth->execute($blog_id, $like, $like,$like,$limit, $offset);

    my @entries;
    while (my $row = $sth->fetchrow_hashref) {
        push @entries, MyApp::Entity::Entry->new(%$row);
    }
    return \@entries;
}

sub get_entries_count {
    my ($self, $blog_id, $keyword) = @_;
    #return [] unless defined $keyword && $keyword ne '';
    my $sql;

    if (!defined $keyword || $keyword eq '') {
        $keyword="%";
    }
    $sql = q{
        SELECT COUNT(e.entry_id)
        FROM mt_entry e
        WHERE e.entry_blog_id = ?
          AND e.entry_status = 2
          AND (e.entry_title LIKE ? OR e.entry_text LIKE ? OR e.entry_text_more LIKE ?)
        };

    $sql = $self->make_sql($blog_id, $keyword,1);

    #MyApp::ToolMy::exitError("MyApp::Molde::Entry::get_entries_count #1 \$sql:".$sql,1);


    my $like = '%' . $keyword . '%';
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($blog_id,$like,$like,$like);

    my ($count) = $sth->fetchrow_array;

    #MyApp::ToolMy::exitError("MyApp::Molde::Entry::get_entries_count #9 \$count:".$count,1);

    return $count;
}

sub make_sql{
    my ($self, $blog_id, $keyword,$flg) = @_;
    my $sql='';

    #MyApp::ToolMy::exitError("MyApp::Molde::Entry::make_sql #1 \$$flg:".$flg);

    #  なし -> データの取得
    if(!defined $flg){
        $sql = q{
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
          AND (e.entry_title LIKE ? OR e.entry_text LIKE ? OR e.entry_text_more LIKE ?)
        };
    }
    # 件数の sql
    else{
        $sql = q{
            SELECT COUNT(e.entry_id)
            FROM mt_entry e
            WHERE e.entry_blog_id = ?
            AND e.entry_status = 2
            AND (e.entry_title LIKE ? OR e.entry_text LIKE ?  OR e.entry_text_more LIKE ?)
        };
    }
    return $sql;
}

1;