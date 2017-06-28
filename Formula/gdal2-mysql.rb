class Gdal2Mysql < Formula
  desc "GDAL/OGR 2 plugin for MySQL driver"
  homepage "http://www.gdal.org/drv_mysql.html"
  url "http://download.osgeo.org/gdal/2.2.0/gdal-2.2.0.tar.gz"
  sha256 "d06546a6e34b77566512a2559e9117402320dd9487de9aa95cb8a377815dc360"

  depends_on "mysql" => :build # adds openssl
  depends_on "gdal2"

  def gdal_majmin_ver
    gdal_ver_list = Formula["gdal2"].version.to_s.split(".")
    "#{gdal_ver_list[0]}.#{gdal_ver_list[1]}"
  end

  def gdal_plugins_subdirectory
    "gdalplugins/#{gdal_majmin_ver}"
  end

  def install
    mysql = Formula["mysql"]

    gdal_plugins = lib/gdal_plugins_subdirectory
    gdal_plugins.mkpath
    (HOMEBREW_PREFIX/"lib/#{gdal_plugins_subdirectory}").mkpath

    # cxx flags
    args = %W[-Iport -Igcore -Iogr -Iogr/ogrsf_frmts -Iogr/ogrsf_frmts/generic
              -Iogr/ogrsf_frmts/mysql -I#{mysql.opt_include}/mysql]

    # source files
    Dir["ogr/ogrsf_frmts/mysql/*.c*"].each do |src|
      args.concat %W[#{src}]
    end

    # plugin dylib
    dylib_name = "ogr_MySQL.dylib"
    args.concat %W[
      -dynamiclib
      -install_name #{opt_lib}/#{gdal_plugins_subdirectory}/#{dylib_name}
      -current_version #{version}
      -compatibility_version #{gdal_majmin_ver}.0
      -o #{gdal_plugins}/#{dylib_name}
      -undefined dynamic_lookup
    ]

    # ld flags
    args.concat %W[
      #{mysql.opt_lib}/libmysqlclient.a
      -L#{Formula["openssl"].opt_lib}
      -lssl
      -lcrypto
    ]

    # build and install shared plugin
    system ENV.cxx, *args
  end

  def caveats; <<-EOS.undent
      This formula provides a plugin that allows GDAL or OGR to access geospatial
      data stored in its format. In order to use the shared plugin, you may need
      to set the following enviroment variable:

        export GDAL_DRIVER_PATH=#{HOMEBREW_PREFIX}/lib/gdalplugins
    EOS
  end

  test do
    ENV["GDAL_DRIVER_PATH"] = "#{HOMEBREW_PREFIX}/lib/gdalplugins"
    gdal_opt_bin = Formula["gdal2"].opt_bin
    out = shell_output("#{gdal_opt_bin}/ogrinfo --formats")
    assert_match "MySQL -vector- (rw+)", out
  end
end
