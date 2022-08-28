# README

## Useful Snippets

### Find all teams without participations

```ruby
teams = Team.where.missing(:participations)
```

### Find shinpans in a category

```ruby
category = IndividualCategory.find 31

shinpans = Kenshi.joins(:participations).merge(category.participations).where(grade: %w[5Dan 6Dan 7Dan 8Dan])
```
