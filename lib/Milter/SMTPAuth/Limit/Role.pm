
package Milter::SMTPAuth::Limit::Role;

package Milter::SMTPAuth::Limit::MessageLimitRole;

use Moose::Role;
requires 'get_weight', 'load_config';

1;

