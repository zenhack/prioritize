@0xb516cbb258e014a8;

using Spk = import "/sandstorm/package.capnp";
# This imports:
#   $SANDSTORM_HOME/latest/usr/include/sandstorm/package.capnp
# Check out that file to see the full, documented package definition format.

const pkgdef :Spk.PackageDefinition = (
  # The package definition. Note that the spk tool looks specifically for the
  # "pkgdef" constant.

  id = "nut9xv0zcc4x92udcu9mwrp661xps9ecdtjaffnev34yn2ussvz0",
  # Your app ID is actually its public key. The private key was placed in
  # your keyring. All updates must be signed with the same key.

  manifest = (
    # This manifest is included in your app package to tell Sandstorm
    # about your app.

    appTitle = (defaultText = "Prioritize"),

    appVersion = 12,  # Increment this for every release.

    appMarketingVersion = (defaultText = "0.1.2"),
    # Human-readable representation of appVersion. Should match the way you
    # identify versions of your app in documentation and marketing.

    actions = [
      # Define your "new document" handlers here.
      ( nounPhrase = (defaultText = "task list"),
        command = .myCommand
        # The command to run when starting for the first time. (".myCommand"
        # is just a constant defined at the bottom of the file.)
      )
    ],

    continueCommand = .myCommand,
    # This is the command called to start your app back up after it has been
    # shut down for inactivity. Here we're using the same command as for
    # starting a new instance, but you could use different commands for each
    # case.

    metadata = (
      # Data which is not needed specifically to execute the app, but is useful
      # for purposes like marketing and display.  These fields are documented at
      # https://docs.sandstorm.io/en/latest/developing/publishing-apps/#add-required-metadata
      # and (in deeper detail) in the sandstorm source code, in the Metadata section of
      # https://github.com/sandstorm-io/sandstorm/blob/master/src/sandstorm/package.capnp
      icons = (
        # Various icons to represent the app in various contexts.
        appGrid = (svg = embed "icon.svg"),
        grain = (svg = embed "icon.svg"),
        market = (svg = embed "icon.svg"),
        marketBig = (svg = embed "icon.svg"),
      ),

      website = "https://github.com/zenhack/prioritize",
      # This should be the app's main website url.

      codeUrl = "https://github.com/zenhack/prioritize",
      # URL of the app's source code repository, e.g. a GitHub URL.
      # Required if you specify a license requiring redistributing code, but optional otherwise.

      license = (openSource = apache2),
      # The license this package is distributed under.  See
      # https://docs.sandstorm.io/en/latest/developing/publishing-apps/#license

      categories = [productivity],
      # A list of categories/genres to which this app belongs, sorted with best fit first.
      # See the list of categories at
      # https://docs.sandstorm.io/en/latest/developing/publishing-apps/#categories

      author = (
        # Fields relating to the author of this app.

        contactEmail = "ian@zenhack.net",
        pgpSignature = embed "pgp-signature",
      ),
      pgpKeyring = embed "pgp-keyring",

      description = (defaultText = embed "README.md"),
      # The app's description in Github-flavored Markdown format, to be displayed e.g.
      # in an app store. Note that the Markdown is not permitted to contain HTML nor image tags (but
      # you can include a list of screenshots separately).

      shortDescription = (defaultText = "Schedule periodic tasks"),
      # A very short (one-to-three words) description of what the app does. For example,
      # "Document editor", or "Notetaking", or "Email client". This will be displayed under the app
      # title in the grid view in the app market.

      screenshots = [
        (height = 1125, width = 2436, png = embed "screenshot.png"),
      ],
      changeLog = (defaultText = embed "CHANGELOG.md"),
    ),
  ),

  sourceMap = (
    # Here we defined where to look for files to copy into your package. The
    # `spk dev` command actually figures out what files your app needs
    # automatically by running it on a FUSE filesystem. So, the mappings
    # here are only to tell it where to find files that the app wants.
    searchPath = [
      ( sourcePath = "." ),  # Search this directory first.
      ( sourcePath = "/",    # Then search the system root directory.
        hidePaths = [ "home", "proc", "sys",
                      "etc/passwd", "etc/hosts", "etc/host.conf",
                      "etc/nsswitch.conf", "etc/resolv.conf" ]
        # You probably don't want the app pulling files from these places,
        # so we hide them. Note that /dev, /var, and /tmp are implicitly
        # hidden because Sandstorm itself provides them.
      )
    ]
  ),

  fileList = "sandstorm-files.list",
  # `spk dev` will write a list of all the files your app uses to this file.
  # You should review it later, before shipping your app.

  alwaysInclude = [],
  # Fill this list with more names of files or directories that should be
  # included in your package, even if not listed in sandstorm-files.list.
  # Use this to force-include stuff that you know you need but which may
  # not have been detected as a dependency during `spk dev`. If you list
  # a directory here, its entire contents will be included recursively.

  #bridgeConfig = (
  #  # Used for integrating permissions and roles into the Sandstorm shell
  #  # and for sandstorm-http-bridge to pass to your app.
  #  # Uncomment this block and adjust the permissions and roles to make
  #  # sense for your app.
  #  # For more information, see high-level documentation at
  #  # https://docs.sandstorm.io/en/latest/developing/auth/
  #  # and advanced details in the "BridgeConfig" section of
  #  # https://github.com/sandstorm-io/sandstorm/blob/master/src/sandstorm/package.capnp
  #  viewInfo = (
  #    # For details on the viewInfo field, consult "ViewInfo" in
  #    # https://github.com/sandstorm-io/sandstorm/blob/master/src/sandstorm/grain.capnp
  #
  #    permissions = [
  #    # Permissions which a user may or may not possess.  A user's current
  #    # permissions are passed to the app as a comma-separated list of `name`
  #    # fields in the X-Sandstorm-Permissions header with each request.
  #    #
  #    # IMPORTANT: only ever append to this list!  Reordering or removing fields
  #    # will change behavior and permissions for existing grains!  To deprecate a
  #    # permission, or for more information, see "PermissionDef" in
  #    # https://github.com/sandstorm-io/sandstorm/blob/master/src/sandstorm/grain.capnp
  #      (
  #        name = "editor",
  #        # Name of the permission, used as an identifier for the permission in cases where string
  #        # names are preferred.  Used in sandstorm-http-bridge's X-Sandstorm-Permissions HTTP header.
  #
  #        title = (defaultText = "editor"),
  #        # Display name of the permission, e.g. to display in a checklist of permissions
  #        # that may be assigned when sharing.
  #
  #        description = (defaultText = "grants ability to modify data"),
  #        # Prose describing what this role means, suitable for a tool tip or similar help text.
  #      ),
  #    ],
  #    roles = [
  #      # Roles are logical collections of permissions.  For instance, your app may have
  #      # a "viewer" role and an "editor" role
  #      (
  #        title = (defaultText = "editor"),
  #        # Name of the role.  Shown in the Sandstorm UI to indicate which users have which roles.
  #
  #        permissions  = [true],
  #        # An array indicating which permissions this role carries.
  #        # It should be the same length as the permissions array in
  #        # viewInfo, and the order of the lists must match.
  #
  #        verbPhrase = (defaultText = "can make changes to the document"),
  #        # Brief explanatory text to show in the sharing UI indicating
  #        # what a user assigned this role will be able to do with the grain.
  #
  #        description = (defaultText = "editors may view all site data and change settings."),
  #        # Prose describing what this role means, suitable for a tool tip or similar help text.
  #      ),
  #      (
  #        title = (defaultText = "viewer"),
  #        permissions  = [false],
  #        verbPhrase = (defaultText = "can view the document"),
  #        description = (defaultText = "viewers may view what other users have written."),
  #      ),
  #    ],
  #  ),
  #  #apiPath = "/api",
  #  # Apps can export an API to the world.  The API is to be used primarily by Javascript
  #  # code and native apps, so it can't serve out regular HTML to browsers.  If a request
  #  # comes in to your app's API, sandstorm-http-bridge will prefix the request's path with
  #  # this string, if specified.
  #),
);

const myCommand :Spk.Manifest.Command = (
  # Here we define the command used to start up your server.
  argv = ["/sandstorm-http-bridge", "8000", "--", "/prioritize-app-server"],
  environ = [
    # Note that this defines the *entire* environment seen by your app.
    (key = "PATH", value = "/usr/local/bin:/usr/bin:/bin"),
    (key = "PAPP_DATA_DIR", value = "/var"),
  ]
);
