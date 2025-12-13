# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     LocalCafe.Repo.insert!(%LocalCafe.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Skip seeding in test environment
if Mix.env() == :test do
  IO.puts("Skipping seed in test environment")
  System.halt(0)
end

alias LocalCafe.Repo
alias LocalCafe.Accounts.User
alias LocalCafe.Accounts.Scope
alias LocalCafe.Posts.Post
alias LocalCafe.Locations.Location
alias LocalCafe.HeroSlides.HeroSlide

# Create or get admin user
IO.puts("Creating admin user...")

admin =
  case Repo.get_by(User, email: "hello@fullstack.ing") do
    nil ->
      %User{}
      |> User.email_changeset(%{email: "hello@fullstack.ing"})
      |> User.password_changeset(%{password: "asdfasdfasdfasdf"})
      |> Ecto.Changeset.put_change(:admin, true)
      |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
      |> Repo.insert!()

    user ->
      user
  end

IO.puts("✓ Admin user ready: #{admin.email}")

admin_scope = %Scope{user: admin}

# Clear existing data
IO.puts("Clearing existing data...")

alias LocalCafe.Menu
alias LocalCafe.Tags.Tag
alias LocalCafe.Orders.Order
alias LocalCafe.Orders.OrderLineItem

import Ecto.Query

IO.puts("✓ Cleared existing data")

# Create locations
IO.puts("Creating locations...")

downtown_location =
  Repo.insert!(%Location{
    name: "Downtown",
    slug: "downtown",
    street: "123 Main Street",
    city_state: "Seattle, WA 98101",
    phone: "(206) 555-0100",
    email: "downtown@localcafe.org",
    hours: [
      "Mon-Thu: 7:00 AM - 9:00 PM",
      "Fri: 7:00 AM - 10:00 PM",
      "Sat: 8:00 AM - 10:00 PM",
      "Sun: 8:00 AM - 8:00 PM"
    ],
    description:
      "Our flagship location in the heart of downtown Seattle. Featuring our full menu and cozy indoor seating.",
    image: %{
      full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765347161938-6akz34.webp"
    },
    active: true
  })

waterfront_location =
  Repo.insert!(%Location{
    name: "Waterfront",
    slug: "waterfront",
    street: "456 Harbor Avenue",
    city_state: "Seattle, WA 98121",
    phone: "(206) 555-0200",
    email: "waterfront@localcafe.org",
    hours: [
      "Mon-Thu: 8:00 AM - 8:00 PM",
      "Fri: 8:00 AM - 9:00 PM",
      "Sat: 9:00 AM - 9:00 PM",
      "Sun: 9:00 AM - 7:00 PM"
    ],
    description:
      "Scenic waterfront location with outdoor patio seating and beautiful views of the Sound.",
    image: %{
      full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765388126577-ddwo3k.webp"
    },
    active: true
  })

IO.puts("  ✓ Created: #{downtown_location.name}")
IO.puts("  ✓ Created: #{waterfront_location.name}")
IO.puts("✓ Locations created successfully")

# Create hero slides
IO.puts("Creating hero slides...")

hero_slides = [
  %{
    tagline: "LocalCafe.org - Opensource site for restaurants",
    image: %{
      full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765138064014-ppf6s0.webp",
      thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765138064014-i0lfc8.webp",
      filename: "hero-pasta.jpg"
    },
    position: 0,
    active: true,
    user_id: admin.id
  },
  %{
    tagline: "Full featured - Online orders - Stripe payments - Push notification order status",
    image: %{
      full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765346861297-a17x54.webp",
      thumb_url: "https://blob.fullstack.ing/localcafe/photos/large-1765340437856-pj0rae.webp",
      filename: "hero-kitchen.jpg"
    },
    position: 1,
    active: true,
    user_id: admin.id
  },
  %{
    tagline: "New Features being added - Activlty being developed",
    image: %{
      full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765347430795-0vb70k.webp",
      thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765347430794-ukr0as.webp",
      filename: "hero-locations.jpg"
    },
    position: 2,
    active: true,
    user_id: admin.id
  }
]

Enum.each(hero_slides, fn slide ->
  hero_slide = Repo.insert!(struct(HeroSlide, slide))
  IO.puts("  ✓ Created: #{hero_slide.tagline}")
end)

IO.puts("✓ Hero slides created successfully")

# Create menu items
IO.puts("Creating menu items...")

# Create tags first
vegetarian_tag = Repo.insert!(%Tag{name: "vegetarian"})
vegan_tag = Repo.insert!(%Tag{name: "vegan"})
gluten_free_tag = Repo.insert!(%Tag{name: "gluten-free"})
bestseller_tag = Repo.insert!(%Tag{name: "bestseller"})
spicy_tag = Repo.insert!(%Tag{name: "spicy"})
pasta_tag = Repo.insert!(%Tag{name: "pasta"})
drink_tag = Repo.insert!(%Tag{name: "drinks"})
side_tag = Repo.insert!(%Tag{name: "sides"})

menu_items = [
  # PASTA DISHES
  %{
    title: "Spaghetti Carbonara",
    slug: "spaghetti-carbonara",
    description:
      "Classic Roman pasta with crispy pancetta, egg yolk, pecorino romano, and black pepper. Creamy without cream.",
    available: true,
    position: 1,
    special: true,
    prices: [
      %{label: nil, amount: 1650, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765144814201-hxfas5.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765138072793-jwjl2z.webp",
        filename: "spaghetti-carbonara.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Add Extra Pancetta", price: 300, position: 0},
      %{name: "Extra Pecorino", price: 150, position: 1}
    ],
    tags: [bestseller_tag, pasta_tag]
  },
  %{
    title: "Fettuccine Alfredo",
    slug: "fettuccine-alfredo",
    description:
      "Rich and creamy fettuccine with butter, heavy cream, and fresh parmesan cheese. Simple and indulgent.",
    available: true,
    position: 2,
    prices: [
      %{label: nil, amount: 1550, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765340241684-qxuhzi.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765340241683-gybp1o.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Add Grilled Chicken", price: 400, position: 0},
      %{name: "Add Shrimp", price: 500, position: 1},
      %{name: "Extra Parmesan", price: 150, position: 2}
    ],
    tags: [vegetarian_tag, pasta_tag]
  },
  %{
    title: "Penne Arrabbiata",
    slug: "penne-arrabbiata",
    description:
      "Spicy tomato sauce with garlic, red chili flakes, and fresh basil. A fiery classic from Rome.",
    available: true,
    position: 3,
    prices: [
      %{label: nil, amount: 1450, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765346967873-u4164q.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765346967873-r7az11.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Extra Spicy", price: 0, position: 0},
      %{name: "Add Olives", price: 100, position: 1}
    ],
    tags: [vegan_tag, spicy_tag, pasta_tag]
  },
  %{
    title: "Lasagna Bolognese",
    slug: "lasagna-bolognese",
    description:
      "Layered pasta with rich meat sauce, creamy bechamel, and melted mozzarella. Baked to perfection.",
    available: true,
    position: 4,
    prices: [
      %{label: nil, amount: 1850, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765346987992-ov59uy.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765346987992-dva7jx.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Extra Cheese", price: 200, position: 0}
    ],
    tags: [bestseller_tag, pasta_tag]
  },
  %{
    title: "Linguine Pesto Genovese",
    slug: "linguine-pesto-genovese",
    description:
      "Fresh basil pesto with pine nuts, garlic, parmesan, and extra virgin olive oil. Topped with cherry tomatoes.",
    available: true,
    position: 5,
    prices: [
      %{label: nil, amount: 1550, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765347032583-ny18ox.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765340388174-l47eci.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Add Grilled Chicken", price: 400, position: 0},
      %{name: "Extra Pine Nuts", price: 150, position: 1}
    ],
    tags: [pasta_tag]
  },
  %{
    title: "Cacio e Pepe",
    slug: "cacio-e-pepe",
    description:
      "Simple yet elegant Roman pasta with pecorino romano cheese and black pepper. Minimalist perfection.",
    available: true,
    position: 6,
    prices: [
      %{label: nil, amount: 1400, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765388407537-sp636p.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765388407537-h9f541.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Extra Pecorino", price: 150, position: 0},
      %{name: "Extra Black Pepper", price: 0, position: 1}
    ],
    tags: [pasta_tag]
  },
  %{
    title: "Spaghetti Aglio e Olio",
    slug: "spaghetti-aglio-e-olio",
    description:
      "Midnight pasta with garlic, olive oil, red pepper flakes, and parsley. Simple ingredients, bold flavor.",
    available: true,
    position: 7,
    prices: [
      %{label: nil, amount: 1350, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765388488117-yw5e51.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765388488117-1cdaq4.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Add Anchovies", price: 200, position: 0},
      %{name: "Extra Garlic", price: 50, position: 1}
    ],
    tags: [spicy_tag, pasta_tag]
  },
  %{
    title: "Ricotta Ravioli with Sage Butter",
    slug: "ricotta-ravioli-sage-butter",
    description:
      "Handmade ravioli filled with ricotta and spinach, served with brown butter and crispy sage leaves.",
    available: true,
    position: 8,
    prices: [
      %{label: nil, amount: 1750, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765388522746-4guqno.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765388522746-hkb2sh.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Extra Sage Butter", price: 150, position: 0},
      %{name: "Add Walnuts", price: 150, position: 1}
    ],
    tags: [bestseller_tag, pasta_tag]
  },
  %{
    title: "Rigatoni alla Vodka",
    slug: "rigatoni-alla-vodka",
    description:
      "Creamy tomato vodka sauce with pancetta, finished with parmesan and fresh basil. Indulgent and smooth.",
    available: true,
    position: 9,
    prices: [
      %{label: nil, amount: 1650, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765388571826-ka6nkc.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765388571826-z4sgb8.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Add Grilled Chicken", price: 400, position: 0},
      %{name: "Extra Pancetta", price: 300, position: 1}
    ],
    tags: [pasta_tag]
  },
  # DRINKS
  %{
    title: "Italian Soda",
    slug: "italian-soda",
    description: "Sparkling water with your choice of flavor syrup and a splash of cream.",
    available: true,
    position: 10,
    prices: [
      %{label: "Lemon", amount: 350, position: 0},
      %{label: "Blood Orange", amount: 350, position: 1},
      %{label: "Raspberry", amount: 350, position: 2}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765388648735-gipxlg.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765388648735-4cjgvr.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [],
    tags: [drink_tag]
  },
  %{
    title: "House Red Wine",
    slug: "house-red-wine",
    description: "Crisp Pinot Grigio with citrus notes and a clean finish.",
    available: true,
    position: 13,
    prices: [
      %{label: "Glass", amount: 800, position: 0},
      %{label: "Bottle", amount: 3200, position: 1}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765389016235-5jgkiu.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765389016235-hghc1p.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [],
    tags: [drink_tag]
  },
  %{
    title: "House White Wine",
    slug: "house-white-wine",
    description: "Crisp Pinot Grigio with citrus notes and a clean finish.",
    available: true,
    position: 13,
    prices: [
      %{label: "Glass", amount: 800, position: 0},
      %{label: "Bottle", amount: 3200, position: 1}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765388694421-d97vct.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765388694420-8dygdw.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [],
    tags: [drink_tag]
  },
  %{
    title: "Cappuccino",
    slug: "cappuccino",
    description: "Classic Italian cappuccino with espresso and steamed milk.",
    available: true,
    position: 15,
    prices: [
      %{label: nil, amount: 450, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765388836910-qvr97t.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765388836910-evzdgk.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Extra Shot", price: 100, position: 0}
    ],
    tags: [drink_tag]
  },
  # SIDES
  %{
    title: "Garlic Bread",
    slug: "garlic-bread",
    description: "Toasted ciabatta with garlic butter, parsley, and parmesan. Served warm.",
    available: true,
    position: 16,
    prices: [
      %{label: nil, amount: 550, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765388895508-gswxcf.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765388895508-2sr8k7.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Extra Garlic", price: 50, position: 0},
      %{name: "Add Mozzarella", price: 200, position: 1}
    ],
    tags: [side_tag]
  },
  %{
    title: "Caesar Salad",
    slug: "caesar-salad",
    description: "Crisp romaine lettuce with caesar dressing, croutons, and shaved parmesan.",
    available: true,
    position: 17,
    prices: [
      %{label: nil, amount: 850, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765389109049-hvgk98.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765389109048-tljbfd.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [
      %{name: "Add Grilled Chicken", price: 400, position: 0},
      %{name: "Add Anchovies", price: 200, position: 1}
    ],
    tags: [side_tag, vegetarian_tag]
  },
  %{
    title: "Bruschetta",
    slug: "bruschetta",
    description:
      "Grilled bread topped with diced tomatoes, garlic, basil, and extra virgin olive oil.",
    available: true,
    position: 19,
    prices: [
      %{label: nil, amount: 650, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765389148985-kjf5w9.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765389148984-xsi7p5.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [],
    tags: [side_tag]
  },
  %{
    title: "Tiramisu",
    slug: "tiramisu",
    description:
      "Classic Italian dessert with espresso-soaked ladyfingers, mascarpone cream, and cocoa powder.",
    available: true,
    position: 21,
    prices: [
      %{label: nil, amount: 850, position: 0}
    ],
    images: [
      %{
        full_url: "https://blob.fullstack.ing/localcafe/photos/large-1765388965937-zzcida.webp",
        thumb_url: "https://blob.fullstack.ing/localcafe/photos/thumb-1765388965937-4sympk.webp",
        filename: "placeholder.jpg",
        position: 0,
        primary: true
      }
    ],
    variants: [],
    tags: [side_tag, bestseller_tag]
  }
]

Enum.with_index(menu_items, fn item, idx ->
  tags = Map.get(item, :tags, [])
  item_without_tags = Map.delete(item, :tags)

  {:ok, menu_item} = Menu.create_menu_item(admin_scope, item_without_tags)

  # Associate tags
  menu_item = Repo.preload(menu_item, :tags)
  changeset = Ecto.Changeset.change(menu_item) |> Ecto.Changeset.put_assoc(:tags, tags)
  menu_item = Repo.update!(changeset)

  # Assign locations to menu items
  # Most items available at both locations, but some are location-exclusive
  locations =
    case idx do
      # Tiramisu - Downtown only
      1 ->
        [downtown_location]

      0 ->
        [downtown_location]

      # Ricotta Ravioli - Waterfront only
      7 ->
        [waterfront_location]

      # Rigatoni alla Vodka - Waterfront only
      8 ->
        [waterfront_location]

      # All other items available at both locations
      _ ->
        []
    end

  # Associate locations
  menu_item = Repo.preload(menu_item, :locations)
  changeset = Ecto.Changeset.change(menu_item) |> Ecto.Changeset.put_assoc(:locations, locations)
  Repo.update!(changeset)

  location_names = Enum.map(locations, & &1.name) |> Enum.join(", ")
  IO.puts("  ✓ Created: #{menu_item.title} (#{location_names})")
end)

IO.puts("✓ Menu items created successfully")
