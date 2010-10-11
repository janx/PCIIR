# A dictionary of movie critics and their ratings of a small set of movies
CRITICS = {
  'Lisa Rose' => {'Lady in the Water' => 2.5, 'Snakes on a Plane' => 3.5, 'Just My Luck' => 3.0, 'Superman Returns' => 3.5, 'You, Me and Dupree' => 2.5, 'The Night Listener' => 3.0},
  'Gene Seymour' => {'Lady in the Water' => 3.0, 'Snakes on a Plane' => 3.5, 'Just My Luck' => 1.5, 'Superman Returns' => 5.0, 'The Night Listener' => 3.0, 'You, Me and Dupree' => 3.5},
  'Michael Phillips' => {'Lady in the Water' => 2.5, 'Snakes on a Plane' => 3.0, 'Superman Returns' => 3.5, 'The Night Listener' => 4.0},
  'Claudia Puig' => {'Snakes on a Plane' => 3.5, 'Just My Luck' => 3.0, 'The Night Listener' => 4.5, 'Superman Returns' => 4.0, 'You, Me and Dupree' => 2.5},
  'Mick LaSalle' => {'Lady in the Water' => 3.0, 'Snakes on a Plane' => 4.0, 'Just My Luck' => 2.0, 'Superman Returns' => 3.0, 'The Night Listener' => 3.0, 'You, Me and Dupree' => 2.0},
  'Jack Matthews' => {'Lady in the Water' => 3.0, 'Snakes on a Plane' => 4.0, 'The Night Listener' => 3.0, 'Superman Returns' => 5.0, 'You, Me and Dupree' => 3.5},
  'Toby' => {'Snakes on a Plane' => 4.5,'You, Me and Dupree' => 1.0,'Superman Returns' => 4.0}
}

module PCI
  module Recommendations
    class Base
      def initialize(data)
        @user_based_dataset = data
        @item_based_dataset = transform(data)
        self.dataset_type = :user_based
      end

      def dataset
        @dataset
      end

      def dataset_type=(type=:user_based)
        @dataset = instance_variable_get("@#{type}_dataset")
      end

      def similar_score(person1, person2)
        raise "Not Implement Yet"
      end

      def top_matches(person, n=5)
        scores = other_than(person).map {|other|
          [similar_score(person, other), other]
        }

        scores = scores.sort {|a, b| b[0] <=> a[0]}
        scores[0...n]
      end

      def get_recommendations(person)
        totals = Hash.new(0)
        similar_score_sums = Hash.new(0)

        other_than(person).each {|other|
          sim = similar_score(person, other)
          if sim > 0
            dataset[other].each {|name, score|
              unless dataset[person].has_key?(name) && dataset[person][name] > 0
                totals[name] += @dataset[other][name]*sim
                similar_score_sums[name] += sim
              end
            }
          end
        }

        totals.map {|name, total|
          [total/similar_score_sums[name], name]
        }.sort.reverse
      end

      def calculate_similar_items(n=10)
        result = {}

        count = 0
        dataset.each do |item, scores|
          count += 1
          puts("%d / %d" % [count, dataset.size]) if count%100 == 0

          most_similars = top_matches(item, n)
          result[item] = most_similars
        end

        result
      end

      # r = PCI::Recommendations::EuclideanDistance.new(CRITICS)
      # r.dataset_type = :item_based
      # r.get_recommendation_items r.calculate_similar_items, "Toby"
      def get_recommendation_items(similar_items, person)
        scores = Hash.new(0)
        sim_total = Hash.new(0)

        @user_based_dataset[person].each do |name, score|
          similar_items[name].each do |similarity, item|
            unless @user_based_dataset[person].has_key?(item)
              scores[item] += similarity*score
              sim_total[item] += similarity
            end
          end
        end

        scores.map {|name, score| [score/sim_total[name], name]}.sort.reverse
      end

      private

      def other_than(person)
        dataset.keys - [person]
      end

      def common_items(person1, person2)
        return [] unless dataset[person1] && dataset[person2]
        dataset[person1].keys & dataset[person2].keys
      end

      def transform(data)
        result = {}
        
        data.each do |person, scores|
          scores.each do |name, score|
            result[name] ||= {}
            result[name][person] = score
          end
        end

        result
      end
    end

    class EuclideanDistance < Base
      def similar_score(person1, person2)
        ci = common_items(person1, person2)
        return 0 if ci.empty?

        sum_of_squares = ci.inject(0) {|sum, k|
          sum += (dataset[person1][k] - dataset[person2][k])**2
        }

        return 1/(1+sum_of_squares)
      end
    end

    class PearsonCorrelation < Base
      def similar_score(person1, person2)
        ci = common_items(person1, person2)
        return 0 if ci.empty?

        sum1 = sum2 = sum1square = sum2square = psum = 0

        ci.each do |k|
          sum1 += dataset[person1][k]
          sum2 += dataset[person2][k]
          sum1square += dataset[person1][k]**2
          sum2square += dataset[person2][k]**2
          psum += dataset[person1][k]*dataset[person2][k]
        end

        num = psum - (sum1*sum2/ci.size)
        den = Math.sqrt((sum1square - sum1**2/ci.size) * (sum2square - sum2**2/ci.size))
        return 0 if den == 0

        r = num/den
        return r
      end
    end
  end
end
