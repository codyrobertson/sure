class Assistant::Function::CreateCategory < Assistant::Function
  class << self
    def name
      "create_category"
    end

    def description
      <<~INSTRUCTIONS
        Use this to create a new category for organizing transactions.

        Categories can be either "income" or "expense" classification.
        You can optionally create subcategories by specifying a parent category.

        Example - create a simple category:
        ```
        create_category({
          name: "Subscriptions",
          classification: "expense",
          icon: "wifi"
        })
        ```

        Example - create a subcategory:
        ```
        create_category({
          name: "Netflix",
          classification: "expense",
          parent_name: "Subscriptions"
        })
        ```

        Available icons: ambulance, apple, award, baby, badge-dollar-sign, banknote, barcode,
        bar-chart-3, bath, battery, bed-single, beer, bike, bluetooth, bone, book-open,
        briefcase, building, bus, cake, calculator, calendar-range, camera, car, cat,
        circle-dollar-sign, coffee, coins, compass, cookie, cooking-pot, credit-card, dices,
        dog, drama, drill, droplet, drum, dumbbell, film, flame, flower, fuel, gamepad-2,
        gift, glasses, globe, graduation-cap, hammer, hand-helping, headphones, heart,
        heart-pulse, home, ice-cream-cone, key, landmark, laptop, leaf, lightbulb, chart-line,
        luggage, mail, map-pin, mic, monitor, moon, music, package, palette, paw-print,
        pencil, percent, phone, pie-chart, piggy-bank, pill, pizza, plane, plug, power,
        printer, puzzle, receipt, receipt-text, ribbon, scale, scissors, settings, shield,
        shirt, shopping-bag, shopping-cart, smartphone, sparkles, sprout, stethoscope, store,
        sun, tag, target, tent, thermometer, ticket, train, trees, trophy, truck, tv,
        umbrella, users, utensils, video, wallet, wallet-cards, waves, wifi, wine, wrench, zap
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: ["name", "classification"],
      properties: {
        name: {
          type: "string",
          description: "Name of the category"
        },
        classification: {
          type: "string",
          enum: ["income", "expense"],
          description: "Whether this is an income or expense category"
        },
        icon: {
          type: "string",
          description: "Lucide icon name for the category (e.g., 'coffee', 'car', 'home')"
        },
        parent_name: {
          type: "string",
          description: "Name of parent category if creating a subcategory"
        }
      }
    )
  end

  def call(params = {})
    report_progress("Creating category '#{params['name']}'...")

    # Check if category already exists
    existing = family.categories.find_by("LOWER(name) = ?", params["name"].downcase)
    return { error: "Category '#{params['name']}' already exists", category_id: existing.id } if existing

    parent = nil
    if params["parent_name"].present?
      parent = family.categories.find_by("LOWER(name) = ?", params["parent_name"].downcase)
      return { error: "Parent category '#{params['parent_name']}' not found" } if parent.nil?
    end

    category = family.categories.create!(
      name: params["name"],
      classification: params["classification"],
      color: parent&.color || Category::COLORS.sample,
      lucide_icon: params["icon"] || "tag",
      parent: parent
    )
    broadcast_data_changed

    {
      success: true,
      category_id: category.id,
      name: category.name,
      classification: category.classification,
      parent_name: parent&.name
    }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end
end
