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
# Show shinpans with grade and team name or pool number (for Individual Category)
cup = Cup.last
individual_categories = cup.individual_categories
team_categories = cup.team_categories

(individual_categories + team_categories).each do |category|
  shinpans = Kenshi.joins(:participations).merge(category.participations).where(grade: %w[5Dan 6Dan 7Dan])

  CSV.open("/Users/yannis/Dropbox/kendo/kasaharacup/2023/Shinpans/#{category.name.parameterize}.csv", "wb") do |csv|
    csv << ["Name", "Grade", "Team"]
    shinpans.each do |shinpan|
      participation = shinpan.participations.find { |p| p.category == category }
      csv << [shinpan.full_name, shinpan.grade, participation.team&.name.presence || participation.pool_number.presence]
    end
  end
end
```

### Reset pools for an IndividualCategory

```ruby
SmartPooler.new(category).set_pools
```
