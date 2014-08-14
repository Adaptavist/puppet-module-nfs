# == Class: nfs::server
#
# Manages an NFS Server
#
class nfs::server (
  $exports_path   = '/etc/exports',
  $exports_owner  = 'root',
  $exports_group  = 'root',
  $exports_mode   = '0644',
  $bind_path      = undef,    
  $share_path     = undef,
  $share_owner    = undef,
  $share_mode     = undef,
  $share_group    = undef,
  $share_clients  = undef,
) inherits nfs {

  #if the share directory is set make sure it exists
  if ($share_path != undef ) {
     #set the real_share_path (used when adding share to exports)
     if ( $bind_path != undef ) {
       $real_share_path=$bind_path
     }
     else {
       $real_share_path=$share_path
     } 
     notify{"The value is: ${real_share_path}": } 
     exec { "mkdir_recurse_${share_path}":
       path => [ '/bin', '/usr/bin' ],
       command => "mkdir -p ${share_path}",
       unless => "test -d ${share_path}",
    }
    #if custom privileges are set use them (needs owner, group and mode)
    if (($share_owner != undef) and ($share_group != undef) and ($share_mode != undef)) {
      file { $share_path:
        ensure => "directory",
        owner  => $share_owner,
        group  => $share_group, 
        mode   => $share_mode,
      }
    }
  }
  
  #if the bind directory is set make sure it exists
  if ($bind_path != undef ) {
     exec { "mkdir_recurse_${bind_path}":
       path => [ '/bin', '/usr/bin' ],
       command => "mkdir -p ${bind_path}",
       unless => "test -d ${bind_path}",
    }
  }


  #if we have a bind_path and an share_path bind one to the other!
  if (($bind_path != undef) and ($share_path != undef )) {
    mount { $bind_path: 
      ensure  => mounted, 
      device  => $share_path, 
      fstype  => 'none', 
      options => 'rw,bind', 
    }
  } 
  # GH: TODO - use file fragment pattern
  file { 'nfs_exports':
    ensure => file,
    path   => $exports_path,
    owner  => $exports_owner,
    group  => $exports_group,
    mode   => $exports_mode,
    notify => Exec['update_nfs_exports'],
  }

  #if the share and clients are set add into /etc/exports
  if (($share_clients != undef) and ($real_share_path != undef)) {
    file_line { 'nfs_exports':
      path => $exports_path,
      line => "$real_share_path  $share_clients",
      notify => Exec['update_nfs_exports'],
    }
  }


  exec { 'update_nfs_exports':
    command     => 'exportfs -ra',
    path        => '/bin:/usr/bin:/sbin:/usr/sbin',
    refreshonly => true,
  }

  Service ['nfs_service'] {
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => File['nfs_exports'],
  }
}
