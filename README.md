# README

## Useful Snippets

### Find all teams without participations

```ruby
teams = Team.where.missing(:participations)
```

### Find all kenshis without participations and purchases

```ruby
kenshis = Kenshi.where.missing(:participations, :purchases)
```

### Find all clubs without kenshis and users

```ruby
clubs = Club.where.missing(:kenshis, :users)
```

### Find shinpans in a category

```ruby
# Show shinpans with grade and pool number (for Individual Category)
category = IndividualCategory.find 31

shinpans = Kenshi.joins(:participations).merge(category.participations).where(grade: %w[5Dan 6Dan 7Dan])

shinpans.map { |s| [s.full_name, s.grade, s.participations.find { |p| p.category == category }.pool_number] }

CSV.open("~/Dropbox/kendo/kasaharacup/2023/TABLEAUX MATCH/SHINPANS/open.csv", "wb") do |csv|
  csv << ["Name", "Grade", "Team"]
  shinpans.each do |shinpan|
    csv << [shinpan.full_name, shinpan.grade, shinpan.participations.find { |p| p.category == category }.team.name]
  end
end

# Show shinpans with grade and team name (for Team Category)
category = TeamCategory.find 8

shinpans.map { |s| [s.full_name, s.grade, s.participations.find { |p| p.category == category }.team.name] }

CSV.open("/Users/yannis/Dropbox/kendo/kasaharacup/2023/TABLEAUX MATCH/SHINPANS/teams.csv", "wb") do |csv|
  csv << ["Name", "Grade", "Team"]
  shinpans.each do |shinpan|
    csv << [shinpan.full_name, shinpan.grade, shinpan.participations.find { |p| p.category == category }.team.name]
  end
end
```

### Reset pools for an IndividualCategory

```ruby
SmartPooler.new(category).set_pools
```
